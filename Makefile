# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: selevray <selevray@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/01/21 14:42:25 by selevray          #+#    #+#              #
#    Updated: 2026/01/23 11:27:40 by selevray         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME        = pipex
CC          = cc
CFLAGS      = -Wall -Wextra -Werror -g3
INCLUDES    = -I./includes

SRCDIR      = srcs
OBJDIR      = objs
INCDIR      = includes
BNSDIR 		= bonus

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

BONUS_FILES = main_bonus.c \
			  exec/exec_bonus.c \
			  utils/ft_split_bonus.c \
			  utils/get_next_line_bonus.c \
			  utils/get_next_line_utils_bonus.c \
			  utils/here_doc_bonus.c \
			  utils/parsing_bonus.c \
			  utils/split_args_bonus.c \
			  utils/utils_bonus.c \
			  utils/split_args_utils_bonus.c

OBJS        = $(addprefix $(OBJDIR)/, $(SRC_FILES:.c=.o))

OBJS_BONUS  = $(addprefix $(OBJDIR)/bonus/, $(BONUS_FILES:.c=.o))

HEADERS     = $(INCDIR)/pipex.h \
			  $(BNSDIR)/includes/pipex_bonus.h

all: $(NAME)

$(NAME): $(OBJS)
	@echo "Création de l'exécutable $(NAME)..."
	$(CC) $(CFLAGS) $(OBJS) -o $(NAME)
	@echo "$(NAME) compilé avec succès !"

$(OBJDIR)/%.o: $(SRCDIR)/%.c $(HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

bonus: $(OBJS_BONUS)
	@echo "Création de l'exécutable pipex_bonus..."
	$(CC) $(CFLAGS) $(OBJS_BONUS) -o pipex_bonus
	@echo "pipex_bonus compilé avec succès !"

$(OBJDIR)/bonus/%.o: $(BNSDIR)/srcs/%.c $(HEADERS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -I./$(BNSDIR)/includes -c $< -o $@

clean:
	@echo "Nettoyage des objets..."
	rm -rf $(OBJDIR)

fclean: clean
	@echo "Suppression de l'exécutable..."
	rm -f $(NAME)
	rm -f pipex_bonus

re: fclean all

.PHONY: all clean fclean re bonus