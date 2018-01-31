#include "Token.h"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <fstream>
#include <map>
#include <string>
#include <thread>
#include <vector>

typedef std::vector<int> Stack;

// modified from http://insanecoding.blogspot.com/2011/11/how-to-read-in-file-in-c.html
std::string read_file(const char *filename) {
  std::ifstream in(filename, std::ios::in | std::ios::binary);
  if(in) {
    std::string contents;
    in.seekg(0, std::ios::end);
    contents.resize(in.tellg());
    in.seekg(0, std::ios::beg);
    in.read(&contents[0], contents.size());
    in.close();
    return contents;
  }
  throw errno;
}

void pause(int n) {
    std::this_thread::sleep_for(std::chrono::seconds(n));
}
void pause() {
    pause(1);
}

std::ostream& operator<<(std::ostream& os, const Stack& stack) {
    os << "[";
    for(auto it = stack.begin(); it != stack.end(); it++) {
        os << *it;
        if(it + 1 != stack.end()) {
            os << " ";
        }
    }
    os << "]";
    return os;
}

const int REGISTER_STACK_PTR = -1;

class Kavod {
private:
    // variables
    std::vector<Token>      program;
    size_t                  pc = 0;
    std::map<int, Stack>    stacks;
    int                     stack_ptr = 0;
    bool                    pause_iter = false;
    // methods
    void step();
    void exec(char);
    void exec_multi(std::string);
    bool running();
    Stack& cur_stack();
    int pop();
    int peek();
    int pop_from(int);
    int peek_from(int);
    void setpos(size_t);
    void push(int);
    void push(std::string);
    void push_to(int, int);
    void push_to(int, std::string);

public:
    Kavod(std::string);
    void run();
    void debug();
};

Kavod::Kavod(std::string carr) {
    program = TokenMachine::tokenize(carr);
    // create the 0th stack
    stacks[0];
}

int Kavod::pop() {
    return pop_from(stack_ptr);
}

int Kavod::peek() {
    return peek_from(stack_ptr);
}

int Kavod::pop_from(int ref) {
    if(stacks[ref].empty()) {
        return 0;
    }
    else {
        int res = peek_from(ref);
        stacks[ref].pop_back();
        return res;
    }
}

int Kavod::peek_from(int ref) {
    if(stacks[ref].empty()) {
        return 0;
    }
    else {
        return stacks[ref].back();
    }
}
void Kavod::setpos(size_t size) {
    pc = size;
    
    pause_iter = true;
}

void Kavod::push(int el) {
    push_to(stack_ptr, el);
}

void Kavod::push(std::string str) {
    push_to(stack_ptr, str);
}

void Kavod::push_to(int ref, int el) {
    stacks[ref].push_back(el);
}

void Kavod::push_to(int ref, std::string str) {
    push_to(ref, stoi(str));
}

Stack& Kavod::cur_stack() {
    return stacks[stack_ptr];
}

bool Kavod::running() {
    return pc < program.size();
}

void Kavod::exec(char op) {
    if(op == '#') {
        putchar(pop());
    }
    else if(op == '-') {
        int top = pop(),
            second = pop();
        push(second - top);
    }
    else if(op == '+') {
        int top = pop(),
            second = pop();
        push(second + top);
    }
    else if(op == '>') {
        push_to(REGISTER_STACK_PTR, peek());
    }
    else if(op == '<') {
        push(pop_from(REGISTER_STACK_PTR));
    }
    else if(op == '}') {
        int loc = pop();
        push_to(loc, pop());
    }
    else if(op == '{') {
        int loc = pop();
        push(pop_from(loc));
    }
    else if(op == '~') {
        stack_ptr = pop();
    }
    else if(op == '.') {
        setpos(pop());
    }
    else if(op == '*') {
        push(getchar());
    }
    else if(op == '?') {
        int pos = pop();
        if(peek()) {
            setpos(pos);
        }
    }
    else if(op == '`') {
        debug();
    }
    else {
        std::cerr << "Unimplemented operator " << op << "." << std::endl;
        exit(2);
    }
}

// // unused currently
// void Kavod::exec_multi(std::string str) {
    // if(str == "><") {
        // // duplicate TOS
        // push(peek());
    // }
    // else if(str == "~0~") {
        // // pop TOS, move to stack 0
        // pop();
        // stack_ptr = 0;
    // }
    // else {
        // std::cerr << "Unhandled optimization instruction \"" << str
                  // << "\"." << std::endl;
    // }
// }

void Kavod::step() {
    Token cur = program[pc];
    
    // debug();
    switch(cur.purpose) {
        case TokenType::number:
            push(cur.raw);
            break;
        
        case TokenType::instruction:
            exec(cur.raw[0]);
            break;
        
        // case TokenType::multi:
            // exec_multi(cur.raw);
            // break;
        
        case TokenType::unknown:
            std::cout << "idk: " << cur << std::endl;
            break;
            
        case TokenType::whitespace:
            // do nothing
            break;
    }
    
    // debug();
    // pause();
    
    if(pause_iter) {
        pause_iter = false;
    }
    else {
        pc++;
    }
}

void Kavod::run() {
    while(running()) {
        step();
    }
}

void Kavod::debug() {
    std::cout << "Position: " << pc << std::endl;
    for(auto const& keyPair : stacks) {
        int ref = keyPair.first;
        Stack stack = keyPair.second;
        std::cout << "<" << ref << "> " << stack << std::endl;
    }
}

int main(int argc, char** argv) {
    if(argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <program>" << std::endl;
        return -1;
    }
    std::string program;
    // todo: better arg handler
    if(strcmp(argv[1], "-e") == 0) {
        program = argv[2];
    }
    else if(strcmp(argv[1], "-t") == 0) {
        program = read_file(argv[2]);
        int i = 0;
        for(Token t : TokenMachine::tokenize(program)) {
            std::cout << "Token[" << i << "] = " << t << std::endl;
            i++;
        }
        return 0;
    }
    else {
        program = read_file(argv[1]);
    }
    Kavod inst(program);
    inst.run();
    
    // std::cerr << std::endl;
    // inst.debug();
}