defmodule WarlockTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  doctest Warlock

  setup do
    original_path = System.get_env("PATH")

    on_exit(fn -> restore_path(original_path) end)
  end

  test "finds the best candidate from PATH directories" do
    tmp_directory = System.tmp_dir!()
    test_root = Path.join(tmp_directory, "warlock-test-#{System.unique_integer([:positive])}")

    first_directory = Path.join(test_root, "first")
    second_directory = Path.join(test_root, "second")

    File.mkdir_p!(first_directory)
    File.mkdir_p!(second_directory)
    create_executable(first_directory, "spellcheck")
    create_executable(second_directory, "shellcheck")

    on_exit(fn -> File.rm_rf!(test_root) end)
    System.put_env("PATH", Enum.join([first_directory, second_directory], path_separator()))

    output =
      capture_io(fn ->
        search_options = %{
          algorithm: :jaro_winkler,
          ignore_patterns: [],
          ignored_directories: [],
          num_matches: 1,
          sensitivity: 1.0,
          threshold: 0.8,
          verbose: false
        }

        assert Witch.witch("spelcheck", search_options) == nil
      end)

    assert output =~ "spellcheck"
    refute output =~ "shellcheck"
  end

  test "scores only executable files and preserves PATH precedence" do
    test_root = temporary_test_root("warlock-executable-test")
    first_directory = Path.join(test_root, "first")
    second_directory = Path.join(test_root, "second")
    non_executable = Path.join(first_directory, "spelchek")

    File.mkdir_p!(first_directory)
    File.mkdir_p!(second_directory)
    File.write!(non_executable, "not executable\n")
    first_executable = create_executable(first_directory, "spellcheck")
    create_executable(second_directory, "spellcheck")

    on_exit(fn -> File.rm_rf!(test_root) end)
    System.put_env("PATH", Enum.join([first_directory, second_directory], path_separator()))

    output =
      capture_io(fn ->
        assert Witch.witch("spelchek", search_options(num_matches: 1, threshold: 0.8)) == nil
      end)

    assert output =~ first_executable
    refute output =~ non_executable
  end

  test "uses a later PATH entry when the first matching file is not executable" do
    test_root = temporary_test_root("warlock-path-fallback-test")
    first_directory = Path.join(test_root, "first")
    second_directory = Path.join(test_root, "second")

    File.mkdir_p!(first_directory)
    File.mkdir_p!(second_directory)
    first_directory
    |> Path.join("spellcheck")
    |> File.write!("not executable\n")
    executable = create_executable(second_directory, "spellcheck")

    on_exit(fn -> File.rm_rf!(test_root) end)
    System.put_env("PATH", Enum.join([first_directory, second_directory], path_separator()))

    output =
      capture_io(fn ->
        assert Witch.witch("spelcheck", search_options(num_matches: 1, threshold: 0.8)) == nil
      end)

    assert output =~ executable
  end

  test "normalizes command-line options into search options" do
    args = [
      "--verbose",
      "--sensitivity=.5",
      "--algorithm=lev",
      "--threshold=.8",
      "--matches=3",
      "--ignore=.bat,.cmd",
      "--ignoredir=node_modules,vendor",
      "spellcheck"
    ]

    assert {"spellcheck", search_options} = Argparse.parse_args(args)

    assert search_options == %{
             algorithm: :levenshtein,
             ignore_patterns: [".bat", ".cmd"],
             ignored_directories: ["node_modules", "vendor"],
             num_matches: 3,
             sensitivity: 0.5,
             threshold: 0.8,
             verbose: true
           }
  end

  test "uses command-line search defaults" do
    assert {"spellcheck", search_options} = Argparse.parse_args(["spellcheck"])

    assert search_options == %{
             algorithm: :jaro_winkler,
             ignore_patterns: [],
             ignored_directories: [],
             num_matches: 5,
             sensitivity: 1.0,
             threshold: 0.75,
             verbose: false
           }
  end

  test "preserves representative Jaro-Winkler scores" do
    assert JaroWinkler.similarity("hello", "hallo") == 0.88
    assert JaroWinkler.similarity("martha", "marhta") == 0.9611111111111111
    assert JaroWinkler.similarity("", "") == 1.0
    assert JaroWinkler.similarity("a", "b") == 0.0
    assert JaroWinkler.similarity("SpellCheck", "spellcheck") == 1.0
  end

  test "applies the Winkler prefix adjustment only to strong Jaro matches" do
    first = "abxxxx"
    second = "abyyyy"
    raw_jaro = String.jaro_distance(first, second)

    assert raw_jaro < 0.7
    assert JaroWinkler.similarity(first, second) == raw_jaro
  end

  test "counts extended grapheme clusters in the prepared Winkler prefix" do
    first = "👩‍🔬abc"
    second = "👩‍🔬abd"
    raw_jaro = String.jaro_distance(first, second)
    expected = raw_jaro + 3 * 0.1 * (1.0 - raw_jaro)

    assert_in_delta JaroWinkler.similarity(first, second), expected, 1.0e-12
  end

  test "scores candidates against a pre-normalized query" do
    assert Similaritysearch.similarity_to_normalized_query(
             "spellcheck",
             "SpellCheck",
             1.0,
             :jaro_winkler
           ) == 1.0

    assert Similaritysearch.similarity_to_normalized_query(
             "spellcheck",
             "SpellCheck",
             1.0,
             :levenshtein
           ) == 1.0
  end

  test "threshold-pruned Levenshtein agrees with the exact score" do
    strings = ["", "a", "ab", "kitten", "sitting", "spellcheck", "shellcheck", "café"]

    for query <- strings,
        candidate <- strings,
        sensitivity <- [0.5, 1.0, 2.0],
        threshold <- [0.0, 0.5, 0.75, 1.0] do
      exact = Similaritysearch.similarity(query, candidate, sensitivity, false, :levenshtein)
      prepared_query = Similaritysearch.prepare_query(query, :levenshtein)

      case Similaritysearch.score_candidate(
             prepared_query,
             candidate,
             sensitivity,
             threshold
           ) do
        {:ok, pruned_score} ->
          assert exact >= threshold
          assert_in_delta pruned_score, exact, 1.0e-12

        :below_threshold ->
          assert exact < threshold
      end
    end
  end

  test "shell launcher returns an exact match without a BEAM fallback" do
    test_root =
      Path.join(System.tmp_dir!(), "warlock-launcher-test-#{System.unique_integer([:positive])}")

    executable_directory = Path.join(test_root, "bin")
    launcher = Path.join(test_root, "warlock")
    launcher_source = Path.expand("../warlock", __DIR__)

    File.mkdir_p!(executable_directory)
    File.cp!(launcher_source, launcher)
    File.chmod!(launcher, 0o755)
    executable = create_executable(executable_directory, "spellcheck")

    on_exit(fn -> File.rm_rf!(test_root) end)

    assert {output, 0} =
             System.cmd(launcher, ["spellcheck"], env: [{"PATH", executable_directory}])

    assert String.trim(output) == executable
  end

  defp create_executable(directory, name) do
    path = Path.join(directory, name)
    File.write!(path, "#!/bin/sh\n")
    File.chmod!(path, 0o755)
    path
  end

  defp temporary_test_root(prefix) do
    Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
  end

  defp search_options(overrides) do
    Map.merge(
      %{
        algorithm: :jaro_winkler,
        ignore_patterns: [],
        ignored_directories: [],
        num_matches: 5,
        sensitivity: 1.0,
        threshold: 0.75,
        verbose: false
      },
      Map.new(overrides)
    )
  end

  defp path_separator do
    if match?({:win32, _}, :os.type()), do: ";", else: ":"
  end

  defp restore_path(nil), do: System.delete_env("PATH")
  defp restore_path(path), do: System.put_env("PATH", path)
end
