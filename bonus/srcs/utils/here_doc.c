/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   here_doc.c                                         :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/21 13:08:48 by selevray          #+#    #+#             */
/*   Updated: 2026/02/09 15:06:27 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

void	safe_write(int fd, const void *buf, size_t count)
{
	if (write(fd, buf, count) == -1)
	{
		perror("write");
		exit(1);
	}
}

static void	read_input(char *limiter, int *fd)
{
	char	*line;
	char	*error;

	close(fd[0]);
	error = "\nbash: warning: here-document delimited by end-of-file (wanted '";
	while (1)
	{
		write(1, "> ", 2);
		line = get_next_line(0);
		if (!line)
		{
			ft_putstr_fd(error, 2);
			ft_putstr_fd(limiter, 2);
			ft_putendl_fd("')", 2);
			exit(0);
		}
		if (ft_strncmp(line, limiter, ft_strlen(limiter)) == 0
			&& line[ft_strlen(limiter)] == '\n')
		{
			free(line);
			exit(0);
		}
		safe_write(fd[1], line, ft_strlen(line));
		free(line);
	}
}

int	here_doc(char *limiter)
{
	pid_t	pid;
	int		fd[2];

	if (pipe(fd) == -1)
		exit(1);
	pid = fork();
	if (pid == -1)
		exit(1);
	if (pid == 0)
		read_input(limiter, fd);
	close(fd[1]);
	wait(NULL);
	return (fd[0]);
}
