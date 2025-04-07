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

The above commands will generate an executable named `warlock` in your project directory.

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
   Warlock first attempts to locate an executable that exactly matches the given command name.

3. **Fuzzy Matching:**  
   If no exact match is found, Warlock gathers all executables from your system PATH and calculates similarity scores using a Levenshtein distance algorithm.  
   The sensitivity value affects the substitution cost in the algorithm—lower values make the matching more forgiving, while higher values make it more sensitive.

4. **Results Display:**  
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
└── warlock
```

- **lib/warlock.ex:** Contains the main logic for parsing arguments, searching executables, fuzzy matching, and displaying results.
- **lib/warlock/application.ex:** Contains the OTP application start logic.
- **mix.exs:** The project configuration file.
- **test:** Contains tests for the project.

## Contributing

Contributions are welcome! Feel free to fork the repository and submit pull requests with improvements or fixes. Thanks gamers.

## License

[MIT License](LICENSE)
