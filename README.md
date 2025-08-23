# haiku-gradle-cli

A CLI that scaffolds Gradle projects with best practices. It wraps `gradle init` and adds opinionated templates (version catalogs, CI, editor config) so projects are production-ready out of the box.

## Installation

To install the `haiku-gradle` CLI locally, follow these steps:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/guilhermehbueno/haiku-gradle-cli
    cd haiku-gradle-cli
    ```

2.  **Run the installation script:**
    ```bash
    ./install.sh
    ```
    This will copy the CLI assets to `~/.haiku-gradle-cli` and create a symlink at `~/.local/bin/haiku-gradle`.

3.  **Update your PATH:**
    Ensure `~/.local/bin` is in your shell's `PATH`. You can check with `echo $PATH`. If it's not present, add the following line to your shell's configuration file (e.g., `~/.bashrc`, `~/.zshrc`):
    ```bash
    export PATH="${HOME}/.local/bin:${PATH}"
    ```

4.  **Verify the installation:**
    Open a new terminal session and run:
    ```bash
    haiku-gradle info
    ```

## Usage

To create a new project, use the `init` command:
```bash
haiku-gradle init my-new-app --type app
```
This will create a new Gradle project in the `my-new-app` directory.
