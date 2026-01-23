/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   split_args_bonus.c                                 :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/20 03:19:48 by selevray          #+#    #+#             */
/*   Updated: 2026/01/23 10:54:04 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex_bonus.h"

static char	**free_tab(char **tab)
{
	int	i;

	i = 0;
	while (tab[i])
	{
		free(tab[i]);
		i++;
	}
	free(tab);
	return (NULL);
}

static int	count_words(char const *s)
{
	int	count;
	int	i;

	count = 0;
	i = 0;
	while (s[i])
	{
		while (s[i] == ' ')
			i++;
		if (s[i])
		{
			count++;
			i += get_word_len(s, i);
		}
	}
	return (count);
}

static char	*get_next_word(char const *s, int *index)
{
	char	*word;
	int		len;

	while (s[*index] == ' ')
		(*index)++;
	len = get_word_len(s, *index);
	word = malloc(sizeof(char) * (len + 1));
	if (!word)
		return (NULL);
	fill_word(word, s, *index, len);
	*index += len;
	return (word);
}

char	**ft_split_args(char const *s)
{
	char	**tab;
	int		words;
	int		i;
	int		str_index;

	if (!s)
		return (NULL);
	words = count_words(s);
	tab = malloc(sizeof(char *) * (words + 1));
	if (!tab)
		return (NULL);
	i = 0;
	str_index = 0;
	while (i < words)
	{
		tab[i] = get_next_word(s, &str_index);
		if (!tab[i])
			return (free_tab(tab));
		i++;
	}
	tab[i] = NULL;
	return (tab);
}
