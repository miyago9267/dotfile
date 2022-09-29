// WIP

#include <bits/stdc++.h>
#pragma GCC optimize("O3")
#define endl "\n"
#define endll "\n\n"
#define pb push_back
#define IO ios_base::sync_with_stdio(0);cin.tie(0);cout.sync_with_stdio(0)
#define DD(x) cout << #x << " = " << x << endl
#define DDV(x) for (auto &i:x) cout<<i<<" "; cout<<endl
#define success(x) cout << "\032[0;31m" << x << "\033[0m" << endl
#define warning(x) cout << "\033[0;31m" << x << "\033[0m" << endl
#define info(x) cout << "\034[0;31m" << x << "\033[0m" << endl

using namespace std;

class RunAfterCompiler{
    public:
        class java{
            public:
                void compile(string fileName, vector<string> args){
                    string command = "javac " + fileName;
                    system(command.c_str());
                }
                void run(string fileName, vector<string> args){
                    string command = "java " + fileName + " ";
                    system(command.c_str());
                }
        };

        class cpp{
            public:
                void compile(string fileName, vector<string> args){
                    string command = "g++ -std=c++17 -O2 -Wall -Wextra -Wshadow -Wnon-virtual-dtor -pedantic -Wno-unused-variable -Wno-unused-parameter -Wno-unused-function -Wno-unused-result -Wno-unused-local-typedefs -Wno-unknown-pragmas -Wno-missing-braces -Wno-missing-field-initializers -Wno-parentheses -Wno-switch -Wno-implicit-fallthrough -Wno-reorder -Wno-sign-compare -Wno-strict-aliasing -Wno-strict-overflow -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Wno-unused-result -Wno-unused-local-typedefs -Wno-unknown-pragmas -Wno-missing-braces -Wno-missing-field-initializers -Wno-parentheses -Wno-switch -Wno-implicit-fallthrough -Wno-reorder -Wno-sign-compare -Wno-strict-aliasing -Wno-strict-overflow -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Wno-unused-result -Wno-unused-local-typedefs -Wno-unknown-pragmas -Wno-missing-braces -Wno-missing-field-initializers -Wno-parentheses -Wno-switch -Wno-implicit-fallthrough -Wno-reorder -Wno-sign-compare -Wno-strict-aliasing -Wno-strict-overflow -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Wno-unused-result -Wno-unused-local-typedefs -Wno-unknown-pragmas -Wno-missing-braces -Wno-missing-field-initializers -Wno-parentheses -Wno-switch -Wno-implicit-fallthrough -Wno-reorder -Wno-sign-compare -Wno-strict-aliasing -Wno-strict-overflow -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Wno-unused-result -Wno-unused-local-t";
                    command += " -o " + fileName + ".cpp " + fileName;
                    system(command.c_str());
                }
                void run(string fileName, vector<string> args){
                    string command = "./" + fileName + ".cpp ";
                    system(command.c_str());
                }
        };

        void fileNameCheck(string name, string ext) {
            regex reg = regex("([a-zA-Z0-9_]+).(java|cpp|py)");
            smatch m;
            if (regex_match(name, m, reg)) {
                fileName = m[1], fileExt = m[2];
                if (m[2] != ext) {
                    warning("File extension does not match the language");
                    exit(EXIT_FAILURE);
                }
            } 
            else {
                warning("Invalid file name");
                exit(EXIT_FAILURE);
            }
        }


        RunAfterCompiler(int argCt, char const *argv[]) {
            if (argCt < 3) {
                warning("Usage: rc <cpp/java> <file> [args]");
                exit(1);
            }
            cmdType = string(argv[1]);
            fileName = string(argv[2]);
            fileNameCheck(fileName, cmdType);
            for (auto i=argv+3; i!=argv+argCt; i++) 
                args.push_back(*i);

            if (cmdType == "java") {
                java j;
                j.compile(fileName, args);
                j.run(fileName, args);
            }
            else if (cmdType == "cpp") {
                cpp c;
                c.compile(fileName, args);
                c.run(fileName, args);
            }
            else {
                warning("Invalid language");
                exit(EXIT_FAILURE);
            }
        }
    private:
        bool isDebug = false;
        vector<string> args;
        vector<string> fileTypeList = {"cpp", "java"};
        string fileName, fileExt, filePath, cmdType, cmd;
        map<char, string> cmdList = {
            {'F', " -D DEBUG"}, {'D'," -Wall -g"}
        };
        
    
};

// rc <cpp/java> <file> [args]

signed main(int argCt, char const *argv[]){
    //IO;
    #ifdef DEBUG
		freopen("p.in", "r", stdin);
		freopen("p.out", "w", stdout);
	#endif
    RunAfterCompiler h(argCt, argv);
    return EXIT_SUCCESS;
}
