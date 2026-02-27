/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   pipex.h                                            :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/19 23:10:55 by selevray          #+#    #+#             */
/*   Updated: 2026/02/09 15:06:22 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#ifndef PIPEX_H
# define PIPEX_H

# include <fcntl.h>
# include <stdio.h>
# include <stdlib.h>
# include <sys/types.h>
# include <sys/wait.h>
# include <unistd.h>

int			exec_cmd(char *cmd, char **envp);
void		child_process(char *cmd, char **envp, int fd_in, int *pipefd);
void		run_process(char *cmd, char **envp, int *fd_in);
pid_t		last_process(char *cmd, char **envp, int fd_in, char **argv);

int			wait_all(pid_t last_pid);

char		*find_path_env(char **envp);
char		*get_path_cmd(char *cmd, char **envp);
int			get_word_len(char const *s, int i);
void		fill_word(char *word, char const *s, int i, int len);
char		**ft_split_args(char const *s);

void		free_split(char **tab, int limit);
size_t		ft_strlen(const char *s);
char		*ft_strcat(char *dest, const char *src);
int			ft_strncmp(const char *s1, const char *s2, size_t n);
char		*ft_strcpy(char *dest, const char *src);
char		*ft_strdup(const char *s);
char		*ft_strjoin(char const *s1, char const *s2);
char		*ft_substr(char const *s, unsigned int start, size_t len);
char		*ft_strchr(const char *s, int c);
char		**ft_split(char const *s, char c);
void		ft_putendl_fd(char *s, int fd);
void		ft_putstr_fd(char *s, int fd);

#endif