/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   split_args.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/20 03:19:48 by selevray          #+#    #+#             */
/*   Updated: 2026/01/21 11:50:42 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex.h"

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
	int		count;
	int		i;
	int		in_quote;
	char	quote_char;

	count = 0;
	i = 0;
	while (s[i])
	{
		while (s[i] == ' ')
			i++;
		if (s[i])
			count++;
		in_quote = 0;
		quote_char = 0;
		while (s[i] && (s[i] != ' ' || in_quote))
		{
			if ((s[i] == '\'' || s[i] == '"') && !in_quote)
			{
				in_quote = 1;
				quote_char = s[i];
			}
			else if (s[i] == quote_char && in_quote)
				in_quote = 0;
			i++;
		}
	}
	return (count);
}

static char	*get_next_word(char const *s, int *index)
{
	char	*word;
	int		len;
	int		i;
	int		j;
	char	quote;

	while (s[*index] == ' ')
		(*index)++;
	len = 0;
	quote = 0;
	while (s[*index + len] && (s[*index + len] != ' ' || quote))
	{
		if ((s[*index + len] == '\'' || s[*index + len] == '\"') && !quote)
			quote = s[*index + len];
		else if (s[*index + len] == quote)
			quote = 0;
		len++;
	}
	word = malloc(sizeof(char) * (len + 1));
	if (!word)
		return (NULL);
	i = 0;
	j = 0;
	quote = 0;
	while (i < len)
	{
		if ((s[*index + i] == '\'' || s[*index + i] == '\"') && !quote)
			quote = s[*index + i];
		else if (s[*index + i] == quote)
			quote = 0;
		else
			word[j++] = s[*index + i];
		i++;
	}
	word[j] = '\0';
	*index += len;
	return (word);
}

char	**ft_split_args(char const *s)
{
	char **tab;
	int words;
	int i;
	int str_index;

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
