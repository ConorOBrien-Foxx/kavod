#include "Token.h"
#include <cctype>

TokenMachine::TokenMachine(std::string str) {
    consume = str;
    if(str.empty()) {
        return;
    }
    current = str[0];
}

int is_instruction(char c) {
    return INSTRUCTIONS.find(c) != std::string::npos;
}

std::string token_type_str(TokenType t) {
    switch(t) {
        case TokenType::number:
            return "number";
        case TokenType::instruction:
            return "instruction";
        case TokenType::unknown:
            return "unknown";
        default:
            return "(unimplemented)";
    }
}

std::ostream& operator<<(std::ostream& os, const TokenType& t) {
    return os << token_type_str(t);
}

std::ostream& operator<<(std::ostream& os, const Token& t) {
    return os << "Token(" << t.purpose << ", " << t.raw << ")";
}

void TokenMachine::advance() {
    current = consume[++position];
}

void TokenMachine::advance(size_t n) {
    current = consume[position += n];
}

bool TokenMachine::running() {
    return position < consume.size();
}

bool TokenMachine::needle(std::string str) {
    return consume.find(str, position) == position;
}

// size_t TokenMachine::findMulti() {
    // for(size_t i = 0; i < OPTIMIZE.size(); i++) {
        // if(needle(OPTIMIZE[i])) {
            // return i;
        // }
    // }
    // return std::string::npos;
// }

// reads a single token
void TokenMachine::emit() {
    if(!running())
        return;
    
    Token result;
    result.start = position;
    
    // identify optimizations
    
    // size_t ind;
    
    // if((ind = findMulti()) != std::string::npos) {
        // result.purpose = TokenType::multi;
        // result.raw += OPTIMIZE[ind];
        // advance(result.raw.size());
    // }
    // else
    if(isdigit(current)) {
        result.purpose = TokenType::number;
        
        while(isdigit(current)) {
            result.raw += current;
            advance();
        }
        
    }
    else if(is_instruction(current)) {
        result.purpose = TokenType::instruction;
        result.raw += current;
        advance();
    }
    else if(isspace(current)) {
        result.purpose = TokenType::whitespace;
        
        while(isspace(current)) {
            result.raw += current;
            advance();
        }
    }
    else {
        result.purpose = TokenType::unknown;
        result.raw += current;
        advance();
    }
    
    build.emplace_back(result);
}

void TokenMachine::exhaust() {
    while(running()) {
        emit();
    }
}

std::vector<Token> TokenMachine::tokenize(std::string str) {
    TokenMachine machine (str);
    machine.exhaust();
    return machine.build;
}