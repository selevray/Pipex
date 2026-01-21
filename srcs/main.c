/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/21 13:18:06 by selevray          #+#    #+#             */
/*   Updated: 2026/01/21 16:37:01 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

void	child_process(char *cmd, char **envp, int fd_in, int *pipefd)
{
	close(pipefd[0]);
	if (fd_in == -1)
		exit(1);
	dup2(fd_in, STDIN_FILENO);
	dup2(pipefd[1], STDOUT_FILENO);
	close(fd_in);
	close(pipefd[1]);
	exec_cmd(cmd, envp);
}

int	open_infile(char *file)
{
	int	fd;

	fd = open(file, O_RDONLY);
	if (fd < 0)
		perror(file);
	return (fd);
}

int	wait_all(pid_t last_pid)
{
	int	status;
	int	exit_code;

	waitpid(last_pid, &status, 0);
	while (wait(NULL) > 0)
		;
	if (WIFEXITED(status))
		exit_code = WEXITSTATUS(status);
	else
		exit_code = 127;
	return (exit_code);
}

static int	open_files(int argc, char **argv, int *i, int *fd_in)
{
	int	fd_out;

	if (ft_strncmp(argv[1], "here_doc", 8) == 0)
	{
		if (argc < 6)
			exit(1);
		*i = 3;
		fd_out = open(argv[argc - 1], O_WRONLY | O_CREAT | O_APPEND, 0644);
		*fd_in = here_doc(argv[2]);
	}
	else
	{
		*i = 2;
		fd_out = open(argv[argc - 1], O_WRONLY | O_CREAT | O_TRUNC, 0644);
		*fd_in = open(argv[1], O_RDONLY);
		if (*fd_in < 0)
			perror(argv[1]);
	}
	return (fd_out);
}

int	main(int argc, char **argv, char **envp)
{
	int		i;
	int		fd_in;
	int		fd_out;
	pid_t	last_pid;

	if (argc < 5)
		return (1);
	fd_out = open_files(argc, argv, &i, &fd_in);
	if (fd_out < 0)
		perror(argv[argc - 1]);
	else
		close(fd_out);
	while (i < argc - 2)
	{
		run_process(argv[i], envp, &fd_in);
		i++;
	}
	last_pid = last_process(argv[argc - 2], envp, fd_in, argv);
	if (fd_in != -1)
		close(fd_in);
	return (wait_all(last_pid));
}
