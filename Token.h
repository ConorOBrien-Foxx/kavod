#include <vector>
#include <iostream>
#include <ostream>
#include <string>

const std::string INSTRUCTIONS = "-+.?~*#><}{`";
// const std::vector<std::string> OPTIMIZE = {
    // "><",
    // "~0~"
// };

enum class TokenType {
    number, instruction, /*multi,*/ whitespace, unknown
};

struct Token {
    TokenType       purpose;
    std::string     raw;
    size_t          start;
};

std::string token_type_str(TokenType);

std::ostream& operator<<(std::ostream&, const TokenType&);
std::ostream& operator<<(std::ostream&, const Token&);

int is_instruction(char);

class TokenMachine {
private:
    // variables
    std::vector<Token>  build;
    std::string         consume;
    size_t              position = 0;
    char                current;
    // methods
    void advance();
    void advance(size_t);
    bool running();
    bool needle(std::string);
    size_t findMulti();
public:
    TokenMachine(std::string);
    void emit();
    void exhaust();
    
    static std::vector<Token> tokenize(std::string);
};