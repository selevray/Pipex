/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   parsing.c                                          :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/19 23:11:43 by selevray          #+#    #+#             */
/*   Updated: 2026/01/21 11:54:59 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

char	*find_path_env(char **envp)
{
	int	i;

	i = 0;
	if (envp == NULL)
		perror("Environment variables not found");
	while (envp[i])
	{
		if (ft_strncmp(envp[i], "PATH=", 5) == 0)
			return (envp[i] + 5);
		i++;
	}
	return (NULL);
}

char	*get_path_cmd(char *cmd, char **envp)
{
	char	*path_env;
	char	**paths;
	char	*full_path;
	int		i;

	if (ft_strchr(cmd, '/'))
	{
		if (access(cmd, X_OK) == 0)
			return (ft_strdup(cmd));
		else
			return (NULL);
	}
	path_env = find_path_env(envp);
	if (!path_env)
		path_env = "/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin";
	paths = ft_split(path_env, ':');
	if (!paths)
		return (NULL);
	i = 0;
	while (paths[i])
	{
		full_path = malloc(ft_strlen(paths[i]) + ft_strlen(cmd) + 2);
		if (!full_path)
		{
			free_split(paths, i);
			return (NULL);
		}
		ft_strcpy(full_path, paths[i]);
		ft_strcat(full_path, "/");
		ft_strcat(full_path, cmd);
		if (access(full_path, X_OK) == 0)
		{
			free_split(paths, i + 1);
			return (full_path);
		}
		free(full_path);
		i++;
	}
	free_split(paths, i);
	return (NULL);
}
