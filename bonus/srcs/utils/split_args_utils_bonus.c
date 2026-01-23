/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   split_args_utils_bonus.c                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: selevray <selevray@student.42.fr>          +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/01/21 16:16:44 by selevray          #+#    #+#             */
/*   Updated: 2026/01/23 10:54:10 by selevray         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "pipex_bonus.h"

int	get_word_len(char const *s, int i)
{
	int		len;
	char	quote;

	len = 0;
	quote = 0;
	while (s[i + len] && (s[i + len] != ' ' || quote))
	{
		if ((s[i + len] == '\'' || s[i + len] == '\"') && !quote)
			quote = s[i + len];
		else if (s[i + len] == quote)
			quote = 0;
		len++;
	}
	return (len);
}

void	fill_word(char *word, char const *s, int i, int len)
{
	int		j;
	int		k;
	char	quote;

	j = 0;
	k = 0;
	quote = 0;
	while (j < len)
	{
		if ((s[i + j] == '\'' || s[i + j] == '\"') && !quote)
			quote = s[i + j];
		else if (s[i + j] == quote)
			quote = 0;
		else
			word[k++] = s[i + j];
		j++;
	}
	word[k] = '\0';
}
