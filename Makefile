# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: selevray <selevray@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/01/21 14:42:25 by selevray          #+#    #+#              #
#    Updated: 2026/02/23 12:28:11 by selevray         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #


# Mandatory
NAME        = pipex
CC          = cc
CFLAGS      = -Wall -Wextra -Werror -g3
MANDATORY_DIR = mandatory
MANDATORY_SRCDIR = $(MANDATORY_DIR)/srcs
MANDATORY_INCDIR = $(MANDATORY_DIR)/includes
MANDATORY_OBJDIR = objs/mandatory
MANDATORY_SRC_FILES = main.c \
	exec/exec.c \
	utils/ft_split.c \
	utils/get_next_line_utils.c \
	utils/parsing.c \
	utils/split_args.c \
	utils/utils.c \
	utils/split_args_utils.c
MANDATORY_OBJS = $(addprefix $(MANDATORY_OBJDIR)/, $(MANDATORY_SRC_FILES:.c=.o))
MANDATORY_HEADERS = $(MANDATORY_INCDIR)/pipex.h

# Bonus
NAME_BONUS = pipex_bonus
BONUS_DIR = bonus
BONUS_SRCDIR = $(BONUS_DIR)/srcs
BONUS_INCDIR = $(BONUS_DIR)/includes
BONUS_OBJDIR = objs/bonus
BONUS_SRC_FILES = main.c \
	exec/exec.c \
	utils/ft_split.c \
	utils/get_next_line.c \
	utils/get_next_line_utils.c \
	utils/here_doc.c \
	utils/parsing.c \
	utils/split_args.c \
	utils/utils.c \
	utils/split_args_utils.c
BONUS_OBJS = $(addprefix $(BONUS_OBJDIR)/, $(BONUS_SRC_FILES:.c=.o))
BONUS_HEADERS = $(BONUS_INCDIR)/pipex.h


all: $(NAME)

bonus: $(NAME_BONUS)


$(NAME): $(MANDATORY_OBJS)
	@echo "Création de l'exécutable $(NAME)..."
	$(CC) $(CFLAGS) $(MANDATORY_OBJS) -I$(MANDATORY_INCDIR) -o $(NAME)
	@echo "$(NAME) compilé avec succès !"

$(NAME_BONUS): $(BONUS_OBJS)
	@echo "Création de l'exécutable $(NAME_BONUS)..."
	$(CC) $(CFLAGS) $(BONUS_OBJS) -I$(BONUS_INCDIR) -o $(NAME_BONUS)
	@echo "$(NAME_BONUS) compilé avec succès !"


$(MANDATORY_OBJDIR)/%.o: $(MANDATORY_SRCDIR)/%.c $(MANDATORY_HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -I$(MANDATORY_INCDIR) -c $< -o $@

$(BONUS_OBJDIR)/%.o: $(BONUS_SRCDIR)/%.c $(BONUS_HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -I$(BONUS_INCDIR) -c $< -o $@


clean:
	@echo "Nettoyage des objets..."
	rm -rf objs

fclean: clean
	@echo "Suppression des exécutables..."
	rm -f $(NAME) $(NAME_BONUS)

re: fclean all

.PHONY: all clean fclean re bonus