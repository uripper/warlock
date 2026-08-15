# Warlock

Warlock is a (maybe) smarter implementation of the [`witch`](https://github.com/uripper/witch) command which is a (maybe) smarter implementation of the `which` command. It allows you to search for executables in your system PATH even when the command name is slightly misspelled. Additionally, you can control the sensitivity of the fuzzy matching via a command-line flag.

## Features

- **Fuzzy Matching:**  
  When an exact match is not found, Warlock performs fuzzy matching against all executables in your PATH and displays close matches.

- **Customizable Sensitivity:**  
  Adjust the fuzzy matching sensitivity by using the `--sensitivity` flag. A very low sensitivity will return everything, an extremely high sensitivity may not even return the exact match. Great!

- **Verbose Logging:**  
  Use the `--verbose` flag to see detailed logging output of the search and matching process. Don't do it. You will see information you truly don't care about. Why is it there? Good question!

## Installation

Make sure you have Elixir installed. Then, clone the repository and compile the project:

```bash
git clone https://github.com/your_username/warlock.git
cd warlock
mix deps.get
mix escript.build
```

The build generates `warlock_beam`, the fuzzy-search fallback used by the checked-in
`warlock` launcher. Keep both files together. The launcher resolves the common exact-match
case directly from `PATH`; it starts the BEAM only when fuzzy matching or option handling is
needed.

## Usage

The general usage pattern is:

```bash
./warlock [--verbose] [--sensitivity=VALUE] <command>
```

### Examples

- **Basic usage:**  
  Search for the command `wimich` (a misspelling of `which`):

  ```bash
  ./warlock wimich
  ```

- **Verbose logging:**  
  See detailed logging output while searching:

  ```bash
  ./warlock wimich --verbose
  ```

- **Custom sensitivity:**  
  Adjust the fuzzy matching sensitivity. You can supply the sensitivity as `0.5`, `0.1`, or any other value. The program accepts values starting with a dot (like `.5`) by automatically converting them to `0.5`:

  ```bash
  ./warlock wimich --sensitivity=.5 --verbose
  ```

## How It Works

When you run Warlock, the following happens:

1. **Argument Parsing:**  
   The command-line arguments are parsed using Elixir's `OptionParser`, which extracts:
   - A boolean flag for verbose output (`--verbose`).
   - A sensitivity value for fuzzy matching (`--sensitivity`).
   - The command name to search for.

2. **Exact Match Search:**  
   For a plain command lookup, the lightweight shell launcher searches `PATH` before starting
   the BEAM. Invocations with options are delegated to the full Elixir CLI so validation and
   verbose output remain consistent.

3. **Executable Collection:**

   Warlock scans PATH directories concurrently, preserves PATH precedence, and removes
   non-runnable files before returning suggestions. On WSL-mounted Windows directories,
   command extensions are filtered before scoring so DLLs and resource files are excluded.

4. **Fuzzy Matching:**

   Candidates are scored with Jaro-Winkler by default or Levenshtein when selected. Query
   data is prepared once, and Levenshtein searches stop early when the configured threshold
   can no longer be reached.

5. **Results Display:**

   If close matches (with a similarity score of 0.6 or greater) are found, Warlock displays them in what is possibly a formatted table, with colored highlights showing the differences.

## Development

### Project Structure

```txt
warlock
├── README.md
├── lib
│   ├── warlock
│   │   └── application.ex
│   └── warlock.ex
├── mix.exs
├── test
│   ├── test_helper.exs
│   └── warlock_test.exs
├── warlock
└── warlock_beam
```

- **lib/warlock.ex:** Contains the main logic for parsing arguments, searching executables, fuzzy matching, and displaying results.
- **lib/warlock/application.ex:** Contains the OTP application start logic.
- **mix.exs:** The project configuration file.
- **warlock:** Lightweight exact-match launcher.
- **warlock_beam:** Generated escript used for fuzzy searches and full option handling.
- **test:** Contains tests for the project.

## Contributing

Contributions are welcome! Feel free to fork the repository and submit pull requests with improvements or fixes. Thanks gamers.

## License

[MIT License](LICENSE)
