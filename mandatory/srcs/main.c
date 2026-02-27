/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/21 13:18:06 by selevray          #+#    #+#             */
/*   Updated: 2026/02/05 08:47:35 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

void	child_process(char *cmd, char **envp, int fd_in, int *pipefd)
{
	int	exit_code;

	close(pipefd[0]);
	if (fd_in == -1)
	{
		close(pipefd[1]);
		exit(1);
	}
	dup2(fd_in, STDIN_FILENO);
	dup2(pipefd[1], STDOUT_FILENO);
	close(fd_in);
	close(pipefd[1]);
	exit_code = exec_cmd(cmd, envp);
	close(STDIN_FILENO);
	close(STDOUT_FILENO);
	exit(exit_code);
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
	int		status;
	int		exit_code;
	pid_t	pid;

	exit_code = 0;
	while (1)
	{
		pid = waitpid(-1, &status, 0);
		if (pid == -1)
			break ;
		if (pid == last_pid)
		{
			if (WIFEXITED(status))
				exit_code = WEXITSTATUS(status);
			else
				exit_code = 127;
		}
	}
	return (exit_code);
}

int	main(int argc, char **argv, char **envp)
{
	int		fd_in;
	int		fd_out;
	pid_t	last_pid;

	if (argc != 5)
	{
		ft_putstr_fd("Usage: ./pipex infile cmd1 cmd2 outfile\n", 2);
		return (1);
	}
	fd_in = open(argv[1], O_RDONLY);
	if (fd_in < 0)
		perror(argv[1]);
	fd_out = open(argv[4], O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd_out < 0)
		perror(argv[4]);
	else
		close(fd_out);
	run_process(argv[2], envp, &fd_in);
	last_pid = last_process(argv[3], envp, fd_in, argv);
	if (fd_in != -1)
		close(fd_in);
	return (wait_all(last_pid));
}
