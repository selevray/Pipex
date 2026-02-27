*This project has been created as part of the 42 curriculum by selevray.*

# Pipex

## Description

**Pipex** is a C project from the 42 school curriculum that reproduces the behavior of the Unix pipe mechanism. The goal is to understand how shells handle pipes between processes by reimplementing it from scratch.

The program mimics the following shell behavior:

```sh
< file1 cmd1 | cmd2 > file2
```

It reads input from a file, passes it through one or more commands chained via pipes, and writes the final output to another file. This project covers key Unix concepts such as process creation with `fork`, inter-process communication with `pipe`, file descriptor redirection with `dup2`, and command execution with `execve`.

### Features

- **Mandatory part**: handles exactly 2 commands with 1 pipe, equivalent to `< infile cmd1 | cmd2 > outfile`
- **Bonus part**:
  - Handles **multiple pipes** (unlimited number of commands)
  - Supports `here_doc` mode with `<<` and `>>`, equivalent to `cmd << LIMITER | cmd1 >> file`

---

## Project Structure

```
Pipex/
├── Makefile
├── mandatory/
│   ├── includes/
│   │   └── pipex.h
│   └── srcs/
│       ├── main.c
│       ├── exec/
│       │   └── exec.c
│       └── utils/
│           ├── ft_split.c
│           ├── get_next_line.c
│           ├── get_next_line_utils.c
│           ├── parsing.c
│           ├── split_args.c
│           ├── split_args_utils.c
│           └── utils.c
└── bonus/
    ├── includes/
    │   └── pipex.h
    └── srcs/
        ├── main.c
        ├── exec/
        │   └── exec.c
        └── utils/
            ├── ft_split.c
            ├── get_next_line.c
            ├── get_next_line_utils.c
            ├── here_doc.c
            ├── parsing.c
            ├── split_args.c
            ├── split_args_utils.c
            └── utils.c
```

---

## Instructions

### Requirements

- A C compiler (`cc`)
- A Unix-based system (Linux / macOS)

### Compilation

```sh
# Compile the mandatory part
make

# Compile the bonus part
make bonus

# Clean object files
make clean

# Clean object files and executables
make fclean

# Recompile from scratch
make re
```

This produces two executables:
- `pipex` — mandatory version
- `pipex_bonus` — bonus version

---

## Usage

### Mandatory

```sh
./pipex infile "cmd1" "cmd2" outfile
```

Equivalent to:
```sh
< infile cmd1 | cmd2 > outfile
```

**Examples:**

```sh
./pipex infile "ls -l" "wc -l" outfile
# Equivalent to: < infile ls -l | wc -l > outfile

./pipex infile "grep a1" "wc -w" outfile
# Equivalent to: < infile grep a1 | wc -w > outfile
```

### Bonus — Multiple pipes

```sh
./pipex_bonus file1 cmd1 cmd2 cmd3 ... cmdn file2
```

Equivalent to:
```sh
< file1 cmd1 | cmd2 | cmd3 | ... | cmdn > file2
```

### Bonus — here_doc

```sh
./pipex_bonus here_doc LIMITER cmd cmd1 file
```

Equivalent to:
```sh
cmd << LIMITER | cmd1 >> file
```

The program reads from standard input until the `LIMITER` string is encountered. Output is **appended** to the output file (not truncated).

---

## Technical Details

| Property        | Value                                                                 |
|----------------|-----------------------------------------------------------------------|
| Program Name   | `pipex` / `pipex_bonus`                                               |
| Language        | C                                                                     |
| Compiler flags | `-Wall -Wextra -Werror`                                               |
| Allowed functions | `open`, `close`, `read`, `write`, `malloc`, `free`, `perror`, `strerror`, `access`, `dup`, `dup2`, `execve`, `exit`, `fork`, `pipe`, `unlink`, `wait`, `waitpid` |
| Libft          | Authorized (custom implementation included)                          |
| Norm           | Compliant with 42 Norminette                                         |
| Memory leaks   | None                                                                  |

---

## Resources

### Documentation & References

- [pipe(2) — Linux man page](https://man7.org/linux/man-pages/man2/pipe.2.html)
- [fork(2) — Linux man page](https://man7.org/linux/man-pages/man2/fork.2.html)
- [execve(2) — Linux man page](https://man7.org/linux/man-pages/man2/execve.2.html)
- [dup2(2) — Linux man page](https://man7.org/linux/man-pages/man2/dup.2.html)
- [waitpid(2) — Linux man page](https://man7.org/linux/man-pages/man2/waitpid.2.html)
- [GNU C Library — File Descriptor I/O](https://www.gnu.org/software/libc/manual/html_node/Low_002dLevel-I_002fO.html)

### AI Usage

AI  was used during this project for the following tasks:
- Helping understand error messages
- Clarifying Unix system call documentation and expected behaviors