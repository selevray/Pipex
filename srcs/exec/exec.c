/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   exec.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/21 13:00:28 by selevray          #+#    #+#             */
/*   Updated: 2026/01/21 16:35:11 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

void	exec_cmd(char *cmd, char **envp)
{
	char	**args;
	char	*path;

	args = ft_split_args(cmd);
	if (!args)
		exit(1);
	path = get_path_cmd(args[0], envp);
	if (!path)
	{
		ft_putstr_fd("Command not found: ", 2);
		ft_putendl_fd(args[0], 2);
		free_split(args, -1);
		exit(127);
	}
	execve(path, args, envp);
	perror("Execve failed");
	free(path);
	free_split(args, -1);
	exit(1);
}

void	run_process(char *cmd, char **envp, int *fd_in)
{
	int		pipefd[2];
	pid_t	pid;

	if (pipe(pipefd) == -1)
		exit(1);
	pid = fork();
	if (pid == -1)
		exit(1);
	if (pid == 0)
		child_process(cmd, envp, *fd_in, pipefd);
	else
	{
		close(pipefd[1]);
		if (*fd_in != -1)
			close(*fd_in);
		*fd_in = pipefd[0];
	}
}

static int	get_outfile_fd(char **argv)
{
	int	i;
	int	flag;
	int	fd;

	i = 0;
	while (argv[i])
		i++;
	if (ft_strncmp(argv[1], "here_doc", 8) == 0)
		flag = O_WRONLY | O_CREAT | O_APPEND;
	else
		flag = O_WRONLY | O_CREAT | O_TRUNC;
	fd = open(argv[i - 1], flag, 0644);
	if (fd < 0)
	{
		perror(argv[i - 1]);
		exit(1);
	}
	return (fd);
}

pid_t	last_process(char *cmd, char **envp, int fd_in, char **argv)
{
	pid_t	pid;
	int		fd_out;

	pid = fork();
	if (pid == 0)
	{
		fd_out = get_outfile_fd(argv);
		dup2(fd_in, STDIN_FILENO);
		dup2(fd_out, STDOUT_FILENO);
		close(fd_in);
		close(fd_out);
		exec_cmd(cmd, envp);
	}
	return (pid);
}
