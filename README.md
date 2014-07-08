tmux-initload - tmux initial actions loader
==========

- [Background](#background)
- [Overview](#overview)
- [Installation](#installation)
- [Zsh completion enhancement](#zsh-completion-enhancement)
- [File Format](#file format)
    - [Keys](#keys)
    - [Variables](#variables)
    - [Comment](#comment)
    - [Indent](#indent)
    - [Blank line](#blank-line)
- [Sample initial action files](#sample-initial-action-files)
- [Test Environment](#test-environment)

Background
----------

tmux is a very useful multifunctional terminal multiplexer.
I use tmux habitually, and like tmux's behavior basically. 
But initial actions that are creations of windows/panes, layouts sets, movements between directories, ssh to remote servers and so on become troublesome as tmux is used for various works.

A simple solution of that is coding scripts with tmux commands. However the coding is troublesome, too.

The tmux-initload loads simple format files that present initial actions, and acts according to the contents. It may make some tmux users more happy.

Overview
----------

tmux-initload is a simple bash script. It depends on bash, tmux, and basic Linux/BSD commands. 

Loaded file is comma separated format (key:value). Examples are as follows.

- Open 3 windows and ssh app01, app02, app03 servers. Then hostname command on remote servers are executed

        session: app-ssh-windows
          window-command: ssh ${window}
          window-command: hostname
          window: app{01..03}

- Open 1 window and 5 panes. Then ssh web01 -- web05 servers. Then logs of the web servers are displayed by tail command. At last, the panes are synchronized.

        session: web-log-synced-ssh-panes
          pane-command: ssh ${pane}
          pane-command: tail -f /var/log/httpd/access_log
          pane-sync:
          pane: web{01..05}

The files are expected to be located a certain directory (default: `~/.tmux-initload-conf/`).

tmux-initload is used as follows. 

    $ tmux-initload app-ssh-windows

    $ tmux-initload web-log-synced-ssh-panes

Installation
----------

Installation example is as follows.
In this example, tmux-initload is installed in `~/bin` (The directory is expected to be included in PATH environment variable)

    $ git clone git://github.com/mo-ya/tmux-initload.git

If git is not available in your system, download a zip file from https://github.com/mo-ya/tmux-initload and extract that.

    $ cd tmux-initload
    
    $ cp bin/tmux-initload.sh ~/bin/tmux-initload
    
    $ chmod 755 ~/bin/tmux-initload
    
    $ cp -r conf.samples ~/.tmux-initload-conf

Please test as follows.

    $ tmux-initload install-test

"install-test" session will start. Please check each window.

If the checks pass, installation is completed. 

If you use zsh, usability could be increaced more. Please read next section.

Zsh completion enhancement
----------

Please move the directory where tmux-initload is downloaded. 

    $ cp zsh.completion/zshrc.tmux ~/.zshrc.tmux

Then add a following description into ~/.zshrc under `autoload -U compinit ; compinit` description.

    ZSHRC=${HOME}/.zshrc.tmux
    [ -f ${ZSHRC} ] && source ${ZSHRC}

Setting is completed. After .zshrc is reloaded, input  tmux-initload <TAB>. As a result, config files (and attached/detached sessions) are complemented as follows.

    $ tmux-initload <TAB>

    multi-ssh-windows   -- config
    multi-ssh-windows0  -- attached
    multi-ssh-windows1  -- detached
    no-title            -- config
    no-title0           -- detached
    syncd-ssh-panes     -- config
    tail-webservs-log   -- config
    tail-webservs-log   -- attached

File Format
----------

### Keys

<table>
  <tr>
    <th>Key</th>
    <th>Description</th>
    <th>Position</th>
    <th>Default value</th>
    <th>Available variables</th>
    <th>Comments</th>
  </tr>
  <tr>
    <th>session</th>
    <td>Session name</td>
    <td>Top of a file</td>
    <td>${file}${id}</td>
    <td>${file}, ${id}, ${argv}</td>
    <td>This key is necessary. (Other keys are optional)</td>
  </tr>
  <tr>
    <th>window</th>
    <td>Window name</td>
    <td>Anywhere</td>
    <td>Same as session</td>
    <td>${file}, ${argv}</td>
    <td>If two or more words are specified, multiple windows are created for each word. In addition, brace expansion of bash is available. For example, <code>host{1,2,5}</code> is treated as <code>host1 host2 host5</code>, <code>id{009..012}</code> is treated as <code>id009 id010 id011 id012</code>, and so on. </td>
  </tr>
  <tr>
    <th>window-command</th>
    <td>Command executed in the target window</td>
    <td>Above target <strong>window</strong> description</td>
    <td>nothing</td>
    <td>${file}, ${window}</td>
    <td>The command is executed in each window. ${window} is replaced with value of "window".</td>
  </tr>
  <tr>
    <th>pane</th>
    <td>Pane name</td>
    <td>Below target <strong>window</strong> (If window is nothing, anywhere)</td>
    <td>Same as window</td>
    <td>${file}, ${argv}</td>
    <td>If two or more words are specified, multiple panes are created for each word. Brace expansion of bash is available as same as window. </td>
  </tr>
  <tr>
    <th>pane-command</th>
    <td>Command executed in the target pane</td>
    <td>Above target <strong>pane</strong> description</td>
    <td>nothing</td>
    <td>${file}, ${window}, ${pane}</td>
    <td>The command is executed in each pane. ${pane} and ${window} are replaced with value of "pane" and "window".</td>
  </tr>
  <tr>
    <th>pane-syncd</th>
    <td>Synchronize the target pane (and panes in the same window). The value is ignored.</td>
    <td>Above target <strong>pane</strong> description</td>
    <td>nothing</td>
    <td>none</td>
    <td></td>
  </tr>
  <tr>
    <th>pane-layout</th>
    <td>Set layout</td>
    <td>Above target <strong>pane</strong> description</td>
    <td>even-vertical</td>
    <td>none</td>
    <td>Available values are <strong><a target="_blank" href="http://www.openbsd.org/cgi-bin/man.cgi?query=tmux">layout-names of tmux</a></strong> (ex. even-vertical, tiled, ...)</td>
  </tr>
</table>

### Variables

<table>
  <tr>
    <th>Variable</th>
    <th>Replaced with ...</th>
    <th>Supported keys</th>
    <th>Comments</th>
  </tr>
  <tr>
    <th>${file}</th>
    <td>Initial action file name</td>
    <td>session, window, window-command, pane, pane-command</td>
    <td></td>
  </tr>
  <tr>
    <th>${id}</th>
    <td>Integer (0,1,2,...)</td>
    <td>session</td>
    <td>It is automatically increased, if same number is already used.</td>
  </tr>
  <tr>
    <th>${argv}</th>
    <td>Command line arguments</td>
    <td>session, window, pane</td>
    <td>For example, <code>tmux-initload <file> a b{1,2} c{09..11}</code> is executed, ${argv} is replaced with <code>a b1 b2 c09 c10 c11</code></td>
  </tr>
  <tr>
    <th>${window}</th>
    <td>Value of target window</td>
    <td>window-command, pane-command</td>
    <td></td>
  </tr>
  <tr>
    <th>${pane}</th>
    <td>Value of target pane</td>
    <td>pane-command</td>
    <td></td>
  </tr>
</table>


### Comment

A line with **#** at line head is ignored. That is treated as a comment.


### Indent

Indentation is ignored. Indents in above examples are inserted for readability only.


### Blank line

Blank line is ignored. 

Sample initial action files
----------

See [Samples](./conf.samples)


Test Environment
----------

- Tmux: **1.9a**

- OS, bash
    - OS: **Mac OS X 10.9.4 (Mavericks)**, bash: **GNU bash, version 3.2.51(1)-release**
    - OS: **CentOS 6.5**, bash: **GNU bash, version 4.1.2(1)-release**
