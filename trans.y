%{
#include <stdio.h>
#include <string.h>

#define SYARG_GROUP	0x0001
#define SYARG_KEYWORD	0x0002

#define CLR(arg)	(syargs &= ~(arg))
#define ISSET(arg)	(syargs & (arg))
#define SET(arg)	(syargs |= (arg))

char	outbuf[8096];
char	ungetbuf[64];
int	ungetpos;
int	f_syntax_keyword;
int	f_syntax_region;
int	f_syntax_match;
int	syargs;
%}

%union {
	char	*string;
}

%token	SYNTAX KEYWORD UNKNOWN
%token	CONTAINS ONELINE FOLD DISPLAY EXTEND CONCEALENDS
%token	CONCEAL CCHAR CONTAINED CONTAINEDIN NEXTGROUP TRANSPARENT SKIPWHITE SKIPNL SKIPEMPTY

%token	<string>	group
%token	<string>	sykw_keyword

%%
grammar		: /* empty */
		| grammar '\n'
		| grammar syntax '\n'
		| grammar unknown '\n'
		;

syntax		: SYNTAX KEYWORD group sykw {
			printf("color green \"\\<(%s)\\>\"\n", outbuf);
			f_syntax_keyword = 0;
			outbuf[0] = '\0';
			syargs = 0;
		}
		;

sykw		: sykw_keywords
		| sykw sykw_options
		| sykw_options sykw
		| sykw sykw_keywords

sykw_keywords	: sykw_keywords sykw_keyword {
			strlcat(outbuf, "|", sizeof(outbuf));
			strlcat(outbuf, $2, sizeof(outbuf));
		}
		| sykw_keyword {
			strlcat(outbuf, $1, sizeof(outbuf));
		}
		;

sykw_options	: /* empty */
		| sykw_option
		| sykw_options sykw_option
		;

sykw_option	: CCHAR
		| CONCEAL
		| CONTAINED
		| CONTAINEDIN
		| NEXTGROUP
		| TRANSPARENT
		| SKIPWHITE
		| SKIPNL
		| SKIPEMPTY
		;

unknown		: UNKNOWN
		| unknown UNKNOWN
%%

struct keywords {
	const char	*k_name;
	int	 	 k_val;
};

int
lookup(char *s)
{
	static const struct keywords keywords[] = {
		{"sy",		SYNTAX},
		{"syn",		SYNTAX},
		{"synt",	SYNTAX},
		{"synta",	SYNTAX},
		{"syntax",	SYNTAX},
		{"keyword",	KEYWORD},
		/* options */
		{"contains",	CONTAINS},
		{"oneline",	ONELINE},
		{"fold",	FOLD},
		{"display",	DISPLAY},
		{"extend",	EXTEND},
		{"concealends",	CONCEALENDS},
		{"conceal",	CONCEAL},
		{"cchar",	CCHAR},
		{"contained",	CONTAINED},
		{"containedin",	CONTAINEDIN},
		{"nextgroup",	NEXTGROUP},
		{"transparent",	TRANSPARENT},
		{"skipwhite",	SKIPWHITE},
		{"skipnl",	SKIPNL},
		{"skipempty",	SKIPEMPTY},
	};
	const struct keywords	*p;

	p = keywords;

	do {
		if (strcmp(s, p->k_name) == 0)
			return p->k_val;
	} while (++p < keywords + sizeof(keywords) / sizeof(keywords[0]));

	if (f_syntax_keyword) {
		if (! ISSET(SYARG_GROUP))
			return group;
		else
			return sykw_keyword;
	}

	return UNKNOWN;
}

int
lgetc(void)
{
	if (ungetpos)
		return (unsigned char)ungetbuf[--ungetpos];

	return getchar();
}

int
lungetc(int c)
{
	if (ungetpos + 1 >= 64)
		return EOF;
	ungetbuf[ungetpos++] = c;
	return c;
}

int
yylex(void)
{
	char	 buf[256];
	char	*p;
	int	 c;
	int	 token;

	while ((c = lgetc()) == ' ' || c == '\t')
		; /* nothing */

	if (c == EOF)
		return (0);
	if (c == '\n')
		return '\n';

	p = buf;
	do {
		*p++ = c;
	} while ((c = lgetc()) != ' ' && c != '\t' && c != '\n' && c != EOF);
	*p = '\0';

	if (c == EOF || c == '\n')
		lungetc(c);

	switch (token = lookup(buf)) {
	case SYNTAX:
		f_syntax_keyword = 1;
		return token;
	case group:
		yylval.string = strdup(buf);
		SET(SYARG_GROUP);
		return token;
	case sykw_keyword:
		yylval.string = strdup(buf);
		SET(SYARG_KEYWORD);
		return token;
	default:
		return token;
	}
}

int
yyerror(const char *fmt, ...)
{
	printf("error\n");
	return 0;
}

int
main(void) {
	yyparse();
	return 0;
}
