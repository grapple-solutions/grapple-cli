# grpl Command-Line Client

## Introduction

grpl CLI is tool to manage your grapple apps on kubernetes cluster. grpl provides a guided UI to perform each of its operations which helps the user to interact more freely with the CLI. grpl allows you to do the following
- Create a Cluster
- Install grapple apps on the cluster
- View the status of the cluster
- View Deployment status of the apps installed on the cluster
- Remove apps from the cluster

**STATUS:** This project is currently under active development and maintenance.

## Table of contents

- [Introduction](#introduction)
- [Global Options](#global-options)
- [Set-Up](#set-up)
- [Example](#examples)
## Set-up

grpl CLI is built with Bash and distributed as binary files, available for multiple operating systems

### Installing on macOS

If you have a Mac, you can install it using [Homebrew](https://brew.sh):

```bash
brew tap grapple-solutions/grapple
brew install grapple-cli
```

### Installing on Windows

Will be added Later

### Installing on Linux

Will be added Later


### Running the grpl CLI tool and getting help

To use the tool, simply run `grpl` with your chosen options. You can find context-sensitive help for commands and their options by invoking the `help` or `-h` command:
`grpl help`,
The main components of grpl CLI are outlined in the following sections.

## Global Options

The grpl cli have multiple global options, that you can use, like this:

```
  -h, --help            help for grpl
```

## Examples

```bash
grpl --version
grpl --help
grpl cluster install
```