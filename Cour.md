# PIPEX — 42 Project

> Reproduction du mécanisme de pipe du shell UNIX en C.

```
./pipex infile "cmd1" "cmd2" outfile
```
est l'équivalent exact de :
```bash
< infile cmd1 | cmd2 > outfile
```

---

## Sommaire

1. [Compilation & Usage](#compilation--usage)
2. [Les syscalls fondamentaux](#les-syscalls-fondamentaux)
3. [Architecture generale](#architecture-generale)
4. [Mandatory — Explication fonction par fonction](#mandatory--explication-fonction-par-fonction)
5. [Bonus — Multi-pipes et here_doc](#bonus--multi-pipes-et-here_doc)
6. [Les utilitaires](#les-utilitaires)
7. [Pieges classiques et pourquoi le code les évite](#pieges-classiques-et-pourquoi-le-code-les-évite)

---

## Compilation & Usage

```bash
# Mandatory
make
./pipex infile "grep hello" "wc -l" outfile

# Bonus (multi-pipes + here_doc)
make bonus
./pipex_bonus infile "cmd1" "cmd2" "cmd3" outfile
./pipex_bonus here_doc LIMITER "cmd1" "cmd2" outfile
```

---

## Les syscalls fondamentaux

Avant de lire le code, ces 5 syscalls sont indispensables a comprendre.

### `pipe(int fd[2])`

Crée un tube de communication entre processus.

```
  fd[1] ──────────────────> fd[0]
(écriture)    tube          (lecture)
```

- `fd[1]` : extrémité d'écriture
- `fd[0]` : extrémité de lecture
- Les données écrites dans `fd[1]` peuvent être lues depuis `fd[0]`
- **Bloquant** : `read(fd[0])` attend qu'il y ait des données OU que tous les `fd[1]` soient fermés
- **Crucial** : si `fd[1]` n'est pas fermé par tous les processus qui ne s'en servent pas, le lecteur bloquera indéfiniment

### `fork()`

Duplique le processus courant. Le système d'exploitation crée une **copie exacte** du processus.

```
avant fork()         après fork()
─────────────        ──────────────────────────
  processus    ───>    processus père (PID > 0)
                       processus fils (PID == 0)
```

- Les deux processus reprennent l'exécution juste après `fork()`
- Même code, même mémoire (copiée), mêmes file descriptors ouverts
- Retourne `0` au fils, le `PID` du fils au père, `-1` si erreur

### `dup2(int old_fd, int new_fd)`

Redirige `new_fd` pour qu'il pointe vers la même ressource que `old_fd`.

```
avant dup2(pipe[1], 1)    après dup2(pipe[1], 1)
──────────────────────    ──────────────────────
  0 ──> clavier             0 ──> clavier
  1 ──> terminal            1 ──> pipe[1]  (stdout redirigé !)
  2 ──> terminal            2 ──> terminal
```

- Après le `dup2`, fermer `old_fd` ne ferme pas `new_fd` (ils sont indépendants)
- C'est le mécanisme qui permet de connecter les commandes entre elles

### `execve(char *path, char **argv, char **envp)`

Remplace le processus courant par un programme externe.

```c
execve("/usr/bin/grep", ["grep", "-i", "hello", NULL], envp);
```

- Si `execve` réussit, **il ne retourne jamais** — le code C suivant ne s'exécute pas
- Si `execve` retourne, c'est une erreur
- `path` : chemin absolu de l'exécutable
- `argv` : tableau d'arguments terminé par `NULL`
- `envp` : tableau des variables d'environnement

### `waitpid(pid_t pid, int *status, int options)`

Attend la fin d'un processus fils.

- `pid = -1` : attend n'importe quel fils
- `WIFEXITED(status)` : vrai si le fils a terminé normalement
- `WEXITSTATUS(status)` : récupère le code de retour (`exit(42)` → 42)

---

## Architecture generale

### Le flux de données (mandatory)

```
                    ┌─────────────────────┐
infile ──(fd_in)──> │  child : cmd1       │
                    │  stdin  = fd_in     │
                    │  stdout = pipe[1]   │──> pipe[0] ──(fd_in)──┐
                    └─────────────────────┘                        │
                                                                    v
                                                    ┌─────────────────────┐
                                                    │  last : cmd2        │
                                                    │  stdin  = fd_in     │
                                                    │  stdout = outfile   │
                                                    └─────────────────────┘
```

### Le chainage des fd_in

La variable `fd_in` est le lien entre tous les processus. Elle est passée par **pointeur** a `run_process` pour permettre au père de la modifier :

```
Début          : fd_in = open(infile)        → fd du fichier d'entrée
Apres cmd1     : fd_in = pipefd[0]           → lecture depuis le pipe
Dernier process: dup2(fd_in, STDIN)          → cmd2 lit depuis le pipe
```

---

## Mandatory — Explication fonction par fonction

### `main()` — [mandatory/srcs/main.c:63](mandatory/srcs/main.c#L63)

```c
int main(int argc, char **argv, char **envp)
```

Chef d'orchestre. Exécution en 5 étapes :

**1. Validation des arguments**
```c
if (argc != 5)
    // Usage: ./pipex infile cmd1 cmd2 outfile
```

**2. Ouverture de infile**
```c
fd_in = open(argv[1], O_RDONLY);
```
`fd_in` est le fd courant d'entrée, passé de processus en processus.

**3. Création de outfile (et fermeture immédiate)**
```c
fd_out = open(argv[4], O_WRONLY | O_CREAT | O_TRUNC, 0644);
close(fd_out);
```
Pourquoi ouvrir puis fermer immédiatement ? Pour reproduire exactement le comportement du shell :
le fichier de sortie est crée/tronqué **avant** l'exécution des commandes, même si elles échouent.

**4. Lancement des processus**
```c
run_process(argv[2], envp, &fd_in);          // cmd1 (processus intermédiaire)
last_pid = last_process(argv[3], envp, fd_in, argv);  // cmd2 (dernier processus)
```

**5. Attente et code de retour**
```c
return (wait_all(last_pid));
```
Retourne le code de sortie de la **dernière** commande, comme le shell.

---

### `run_process()` — [mandatory/srcs/exec/exec.c:43](mandatory/srcs/exec/exec.c#L43)

```c
void run_process(char *cmd, char **envp, int *fd_in)
```

Lance un processus intermédiaire (toutes les commandes sauf la dernière).

```
pipe() ──> pipefd[0] (lecture) et pipefd[1] (écriture)
fork()
  ├─ FILS  ──> child_process(cmd, envp, *fd_in, pipefd)
  └─ PÈRE  ──> close(pipefd[1])
               close(*fd_in)
               *fd_in = pipefd[0]    ← le père met à jour fd_in !
```

Le père ferme `pipefd[1]` car il n'écrit pas dans le pipe — seul le fils écrit.
Si le père garde `pipefd[1]` ouvert, le prochain lecteur du pipe ne verra jamais la fin du flux.

`*fd_in = pipefd[0]` est le **chainage** : la sortie de cmd1 devient l'entrée de cmd2.

---

### `child_process()` — [mandatory/srcs/main.c:15](mandatory/srcs/main.c#L15)

```c
void child_process(char *cmd, char **envp, int fd_in, int *pipefd)
```

Executé dans le fils. Configure les redirections et exécute la commande.

```
close(pipefd[0])            → le fils n'a pas besoin de lire depuis ce pipe
si fd_in == -1 : exit(1)    → infile n'a pas pu être ouvert
dup2(fd_in,    STDIN_FILENO)   → stdin  = infile (ou pipe précédent)
dup2(pipefd[1],STDOUT_FILENO)  → stdout = écriture dans le pipe
close(fd_in)                → fd original inutile, dup2 a fait son travail
close(pipefd[1])            → idem
exec_cmd(cmd, envp)         → exécute la commande
```

**Pourquoi fermer les fd après dup2 ?**
`dup2(fd_in, 0)` crée une **copie** du fd dans le slot 0. Le fd original `fd_in` reste ouvert.
Il faut le fermer manuellement pour ne pas avoir de fuite de file descriptors.

---

### `last_process()` — [mandatory/srcs/exec/exec.c:81](mandatory/srcs/exec/exec.c#L81)

```c
pid_t last_process(char *cmd, char **envp, int fd_in, char **argv)
```

Comme `child_process` mais pour la dernière commande. Differences :

| | child_process | last_process |
|---|---|---|
| Sortie | pipe[1] | outfile |
| Pipe créé | oui | non |
| Retourne | void | PID du fils |

Retourne le PID car `wait_all` en a besoin pour identifier le code de sortie de la derniere commande.

La fonction interne `get_outfile_fd()` cherche le dernier argument (`argv[argc-1]`) :
```c
while (argv[i])
    i++;
fd = open(argv[i - 1], O_WRONLY | O_CREAT | O_TRUNC, 0644);
```

---

### `wait_all()` — [mandatory/srcs/main.c:40](mandatory/srcs/main.c#L40)

```c
int wait_all(pid_t last_pid)
```

Attend tous les processus fils et retourne le code de sortie du dernier.

```c
while (1)
{
    pid = waitpid(-1, &status, 0);  // attend n'importe quel fils
    if (pid == -1)
        break;                      // plus aucun fils vivant
    if (pid == last_pid)
        exit_code = WEXITSTATUS(status);  // garde le code du dernier
}
return (exit_code);
```

Pourquoi attendre **tous** les fils et pas seulement le dernier ?
Si on attendait seulement le dernier, les processus intermédiaires deviendraient des **zombies**
(processus terminés dont le père n'a pas récupéré le code de sortie).

---

### `exec_cmd()` — [mandatory/srcs/exec/exec.c:15](mandatory/srcs/exec/exec.c#L15)

```c
void exec_cmd(char *cmd, char **envp)
```

Coeur de l'exécution d'une commande.

```
"grep -i 'hello world'"
        │
        v
ft_split_args()  ──>  ["grep", "-i", "hello world", NULL]
                                │
                                v
get_path_cmd("grep", envp)  ──>  "/usr/bin/grep"
                                │
                                v
execve("/usr/bin/grep", ["grep", "-i", "hello world", NULL], envp)
```

Si la commande n'est pas trouvée → `exit(127)` (convention UNIX : 127 = command not found).

---

### `get_path_cmd()` — [mandatory/srcs/utils/parsing.c:78](mandatory/srcs/utils/parsing.c#L78)

```c
char *get_path_cmd(char *cmd, char **envp)
```

Trouve le chemin absolu d'une commande.

**Cas 1 : chemin absolu ou relatif** (`cmd` contient un `/`)
```c
if (ft_strchr(cmd, '/'))
{
    if (access(cmd, X_OK) == 0)
        return (ft_strdup(cmd));  // utilisable directement
    return (NULL);
}
```

**Cas 2 : commande simple** (`grep`, `cat`, `ls`...)
```
find_path_env(envp) ──> "/usr/local/bin:/usr/bin:/bin"
                            │
                            v
ft_split(path_env, ':') ──> ["/usr/local/bin", "/usr/bin", "/bin", NULL]
                            │
                            v
Pour chaque dossier :
  build_path(dir, cmd) ──> "/usr/bin/grep"
  access(full_path, X_OK) == 0 ? ──> retourne le chemin
```

`access(path, X_OK)` vérifie que le fichier existe ET est exécutable.

---

### `find_path_env()` — [mandatory/srcs/utils/parsing.c:15](mandatory/srcs/utils/parsing.c#L15)

```c
char *find_path_env(char **envp)
```

Parcourt le tableau `envp` pour trouver la variable `PATH`.

```c
// envp ressemble à :
// ["USER=selevray", "PATH=/usr/bin:/bin", "HOME=/home/selevray", NULL]

while (envp[i])
{
    if (ft_strncmp(envp[i], "PATH=", 5) == 0)
        return (envp[i] + 5);  // pointe après le "PATH="
    i++;
}
```

Si `PATH` n'est pas trouvé, un PATH par défaut est utilisé dans `get_path_cmd` :
```c
path_env = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
```

---

### `ft_split_args()` — [mandatory/srcs/utils/split_args.c:65](mandatory/srcs/utils/split_args.c#L65)

```c
char **ft_split_args(char const *s)
```

Découpe une commande en tableau d'arguments en **respectant les quotes**.

Contrairement a `ft_split` qui découpe sur un simple caractere, `ft_split_args` gère :
- Les espaces multiples entre arguments
- Les guillemets simples `'` et doubles `"` qui groupent les mots

```
"grep -i 'hello world'" ──> ["grep", "-i", "hello world", NULL]
"awk '{print $1}'"      ──> ["awk", "{print $1}", NULL]
```

Fonctionnement :
```
count_words(s)           → compte le nombre de tokens (en respectant les quotes)
malloc(words + 1)        → alloue le tableau
Pour chaque token :
  get_next_word(s, &i)
    ├─ saute les espaces
    ├─ get_word_len() → longueur du token (gère les quotes)
    └─ fill_word()    → copie le token (supprime les quotes)
tab[words] = NULL        → terminaison obligatoire pour execve
```

---

### `get_word_len()` et `fill_word()` — [mandatory/srcs/utils/split_args_utils.c](mandatory/srcs/utils/split_args_utils.c)

Ces deux fonctions forment un duo qui gère les quotes.

**`get_word_len(s, i)`** — calcule la longueur d'un token

```c
// Etat machine à deux états : dans une quote ou pas
while (s[i + len] && (s[i + len] != ' ' || quote))
{
    if ((s[i + len] == '\'' || s[i + len] == '"') && !quote)
        quote = s[i + len];       // ouvre une quote
    else if (s[i + len] == quote)
        quote = 0;                // ferme la quote
    len++;
}
```

| Position | Caractere | quote | Action |
|---|---|---|---|
| 0 | `'` | 0 | `quote = '\'`  |
| 1 | `h` | `'` | compte (espace ignoré si présent) |
| ... | ... | ... | ... |
| n | `'` | `'` | `quote = 0` |

**`fill_word(word, s, i, len)`** — copie le token sans les quotes

```c
// Les quotes sont comptées dans la longueur mais pas copiées
if ((s[i + j] == '\'' || ...) && !quote)
    quote = s[i + j];          // ouvre : ne pas copier
else if (s[i + j] == quote)
    quote = 0;                 // ferme : ne pas copier
else
    word[k++] = s[i + j];     // copie le caractere
```

---

## Bonus — Multi-pipes et here_doc

### Multi-pipes — `main()` du bonus — [bonus/srcs/main.c:86](bonus/srcs/main.c#L86)

Le bonus supporte un nombre arbitraire de commandes :
```
./pipex_bonus infile cmd1 cmd2 cmd3 cmd4 outfile
```

La différence avec le mandatory est une simple boucle :

```c
// Mandatory (figé à 1 processus intermédiaire)
run_process(argv[2], envp, &fd_in);
last_pid = last_process(argv[3], envp, fd_in, argv);

// Bonus (boucle sur toutes les commandes intermédiaires)
while (i < argc - 2)
{
    run_process(argv[i], envp, &fd_in);
    i++;
}
last_pid = last_process(argv[argc - 2], envp, fd_in, argv);
```

Le chainage `*fd_in = pipefd[0]` dans `run_process` fait que chaque commande reçoit
automatiquement la sortie de la précédente, quelle que soit leur nombre.

### here_doc — [bonus/srcs/utils/here_doc.c:53](bonus/srcs/utils/here_doc.c#L53)

```
./pipex_bonus here_doc LIMITER cmd1 cmd2 outfile
```

Equivalent shell : `cmd1 << LIMITER | cmd2 >> outfile`

Differences avec le mode normal :
- Input : clavier jusqu'au LIMITER (au lieu d'un fichier)
- Output : mode `O_APPEND` (au lieu de `O_TRUNC`) — bash ajoute au fichier

**`here_doc(char *limiter)`** — retourne un fd lisible

```
pipe() ──> fd[0] (lecture) et fd[1] (écriture)
fork()
  ├─ FILS (read_input) :
  │    close(fd[0])                    ← le fils n'a pas besoin de lire
  │    boucle :
  │      write(1, "> ", 2)             ← affiche le prompt
  │      line = get_next_line(0)       ← lit depuis stdin (clavier)
  │      si line == NULL → EOF détecté, affiche warning, exit(0)
  │      si line == limiter → exit(0)
  │      safe_write(fd[1], line)       ← envoie dans le pipe
  └─ PÈRE :
       close(fd[1])                    ← ferme l'extrémité d'écriture
       wait(NULL)                      ← attend que le fils finisse
       return (fd[0])                  ← retourne le fd de lecture
```

Le `fd[0]` retourné devient le `fd_in` — les commandes lisent depuis ce pipe
exactement comme si c'était un fichier ordinaire.

**`safe_write()`** :
```c
void safe_write(int fd, const void *buf, size_t count)
{
    if (write(fd, buf, count) == -1)
    {
        perror("write");
        exit(1);
    }
}
```
Wrapper autour de `write` qui gère l'erreur — si l'écriture échoue (pipe cassé,
espace disque plein...), on exit proprement au lieu de continuer silencieusement.

---

## Les utilitaires

### `ft_split()` — [mandatory/srcs/utils/ft_split.c](mandatory/srcs/utils/ft_split.c)

Découpe une string sur un caractere séparateur. Utilisée pour parser le PATH :
```c
ft_split("/usr/bin:/bin:/usr/local/bin", ':')
// ──> ["/usr/bin", "/bin", "/usr/local/bin", NULL]
```

Fonctionnement en 3 passes :
1. `count_words(s, c)` — compte les mots (machine à états simple)
2. `malloc` du tableau de pointeurs
3. `fill_split` — extrait chaque mot avec `extract_word`

`free_split(char **tab, int limit)` — libere le tableau :
- `limit == -1` : libère jusqu'au `NULL` terminal (tableau complet)
- `limit == n` : libère seulement les n premières entrées (liberation partielle en cas d'erreur malloc)

### `get_next_line()` — [bonus/srcs/utils/get_next_line.c](bonus/srcs/utils/get_next_line.c)

Lit une ligne depuis un fd. Utilisée uniquement dans le bonus (here_doc).

```
static char *str_static[FD_MAX]   ← buffer persistant entre appels, par fd
```

Fonctionnement :
```
gnl_read(g)
  ├─ lit par blocs de BUFFER_SIZE octets
  ├─ accumule dans str_static avec ft_strjoin
  └─ s'arrête dès qu'il trouve un '\n' ou EOF

extract_line(str_static)   → retourne la ligne jusqu'au '\n' inclus
clean_static(str_static)   → conserve le reste (après '\n') pour l'appel suivant
```

### `utils.c` — [mandatory/srcs/utils/utils.c](mandatory/srcs/utils/utils.c)

Reimplementations des fonctions de la libc interdites a 42 :

| Fonction | Role |
|---|---|
| `ft_strcpy` | Copie une string |
| `ft_strcat` | Concatene deux strings |
| `ft_strncmp` | Compare n caracteres de deux strings |
| `ft_putendl_fd` | Ecrit une string + `\n` sur un fd |
| `ft_putstr_fd` | Ecrit une string sur un fd |

---

## Pieges classiques et pourquoi le code les évite

### 1. Pipe non fermé → blocage infini

**Le piege** : si le père garde `pipefd[1]` ouvert, le prochain `read` sur `pipefd[0]` bloquera
éternellement car le kernel attend que **tous** les writers ferment leur extrémité.

**La solution dans le code** (`run_process`) :
```c
// PÈRE
close(pipefd[1]);   // ← crucial : le père n'écrit pas dans ce pipe
```

### 2. Zombie processes

**Le piege** : si le père ne fait pas `waitpid`, les fils terminent mais restent en mémoire
(état zombie) jusqu'a la fin du père.

**La solution** (`wait_all`) :
```c
while ((pid = waitpid(-1, &status, 0)) != -1)
    ;   // attend TOUS les fils
```

### 3. fd_in = -1 si infile inaccessible

**Le piege** : si `open(infile)` échoue, `fd_in = -1`. Si on passe -1 a `dup2`, comportement indéfini.

**La solution** (dans `child_process` et `last_process`) :
```c
if (fd_in == -1)
{
    close(pipefd[1]);
    exit(1);
}
```
Le processus exit proprement sans tenter le `dup2`.

### 4. outfile crée même si cmd échoue

**Le comportement voulu** (réplication exacte du shell) :
```bash
< /nonexistent cat | grep foo > outfile
# outfile est crée vide même si cat échoue
```

**La solution** : ouvrir outfile dans `main` **avant** de lancer les processus.

### 5. Code de retour du bon processus

**Le piege** : retourner le code de `cmd1` au lieu de `cmd2`.

**La solution** (`wait_all`) : ne retenir que le code du `last_pid`.

### 6. Exécutable sans chemin dans PATH vide

**Le piege** : si `PATH` n'est pas dans `envp` (certains environnements minimalistes).

**La solution** (`get_path_cmd`) :
```c
if (!path_env)
    path_env = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
```

---

## Structure du projet

```
Pipex/
├── Makefile
├── mandatory/
│   ├── includes/
│   │   └── pipex.h
│   └── srcs/
│       ├── main.c               ← main, child_process, wait_all
│       ├── exec/
│       │   └── exec.c           ← exec_cmd, run_process, last_process
│       └── utils/
│           ├── parsing.c        ← find_path_env, get_path_cmd
│           ├── split_args.c     ← ft_split_args
│           ├── split_args_utils.c ← get_word_len, fill_word (gestion quotes)
│           ├── ft_split.c       ← ft_split, free_split
│           └── utils.c          ← ft_strcpy, ft_strcat, ft_strncmp, ft_put*_fd
└── bonus/
    ├── includes/
    │   └── pipex.h
    └── srcs/
        ├── main.c               ← + open_files, boucle multi-pipes
        ├── exec/
        │   └── exec.c           ← identique mandatory
        └── utils/
            ├── here_doc.c       ← here_doc, read_input, safe_write
            ├── get_next_line.c  ← get_next_line (utilisé par here_doc)
            ├── get_next_line_utils.c
            ├── parsing.c
            ├── split_args.c
            ├── split_args_utils.c
            ├── ft_split.c
            └── utils.c
```

---

*selevray — 42*
