/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   get_next_line_bonus.c                              :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2025/11/24 15:20:44 by selevray          #+#    #+#             */
/*   Updated: 2026/01/23 10:53:26 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex_bonus.h"

static char	*extract_line(char *str)
{
	size_t	i;

	i = 0;
	if (!str || !str[0])
		return (NULL);
	while (str[i] && str[i] != '\n')
		i++;
	if (str[i] == '\n')
		return (ft_substr(str, 0, i + 1));
	return (ft_substr(str, 0, i));
}

static char	*clean_static(char *str)
{
	size_t	i;
	char	*result;

	if (!str)
		return (NULL);
	i = 0;
	while (str[i] && str[i] != '\n')
		i++;
	if (!str[i] || !str[i + 1])
	{
		free(str);
		return (NULL);
	}
	result = ft_strdup(str + i + 1);
	free(str);
	return (result);
}

static char	*gnl_read(t_gnl *g)
{
	g->bytes_read = 1;
	while (g->bytes_read > 0 && !ft_strchr(g->str_static, '\n'))
	{
		g->bytes_read = read(g->fd, g->buffer, BUFFER_SIZE);
		if (g->bytes_read < 0)
		{
			free(g->str_static);
			g->str_static = NULL;
			return (NULL);
		}
		if (g->bytes_read == 0)
			break ;
		g->buffer[g->bytes_read] = '\0';
		if (g->str_static)
			g->temp = ft_strjoin(g->str_static, g->buffer);
		else
			g->temp = ft_strdup(g->buffer);
		free(g->str_static);
		g->str_static = g->temp;
	}
	return (g->str_static);
}

char	*get_next_line(int fd)
{
	static char	*str_static[FD_MAX];
	t_gnl		g;
	char		*line;

	if (fd < 0 || fd >= FD_MAX || BUFFER_SIZE <= 0)
		return (NULL);
	g.fd = fd;
	g.str_static = str_static[fd];
	g.buffer = malloc(BUFFER_SIZE + 1);
	if (!g.buffer)
		return (NULL);
	if (!gnl_read(&g))
	{
		free(g.buffer);
		str_static[fd] = NULL;
		return (NULL);
	}
	free(g.buffer);
	line = extract_line(g.str_static);
	str_static[fd] = clean_static(g.str_static);
	return (line);
}
