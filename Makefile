# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: selevray <selevray@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/01/21 14:42:25 by selevray          #+#    #+#              #
#    Updated: 2026/01/21 16:29:00 by selevray         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME        = pipex
CC          = cc
CFLAGS      = -Wall -Wextra -Werror -g3
INCLUDES    = -I./includes

SRCDIR      = srcs
OBJDIR      = objs
INCDIR      = includes

SRC_FILES   = main.c \
			  exec/exec.c \
			  utils/ft_split.c \
			  utils/get_next_line.c \
			  utils/get_next_line_utils.c \
			  utils/here_doc.c \
      		  utils/parsing.c \
			  utils/split_args.c \
			  utils/utils.c \
			  utils/split_args_utils.c \

OBJS        = $(addprefix $(OBJDIR)/, $(SRC_FILES:.c=.o))

HEADERS     = $(INCDIR)/pipex.h

all: $(NAME)

$(NAME): $(OBJS)
	@echo "Création de l'exécutable $(NAME)..."
	$(CC) $(CFLAGS) $(OBJS) -o $(NAME)
	@echo "$(NAME) compilé avec succès !"

$(OBJDIR)/%.o: $(SRCDIR)/%.c $(HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

bonus: $(NAME)
	@echo "Création de l'exécutable $(NAME)..."
	$(CC) $(CFLAGS) $(OBJS) -o pipex_bonus
	@echo "pipex_bonus compilé avec succès !"

clean:
	@echo "Nettoyage des objets..."
	rm -rf $(OBJDIR)

fclean: clean
	@echo "Suppression de l'exécutable..."
	rm -f $(NAME)
	rm -f pipex_bonus

re: fclean all

.PHONY: all clean fclean re bonus