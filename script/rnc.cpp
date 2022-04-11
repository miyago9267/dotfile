// By myg9267
// i m bad in coding, so sad
// it a me mario
#include <bits/stdc++.h>
#pragma GCC optimize("O1")
#pragma GCC optimize("O2")
#pragma GCC optimize("O3")
#define endl "\n"
#define endll "\n\n"
#define pb emplace_back
#define IO ios_base::sync_with_stdio(0);cin.tie(0);cout.sync_with_stdio(0)
#define ll long long
#define MAXN maxn
#define MODN modn

using namespace std;

class helper{
    public:
        bool isExist(string path){
            ifstream fin(path);
            if(fin.is_open()){
                fin.close();
                return true;
            }
            return false;
        }

        bool isCpp(string name){
            if(name.find(".cpp") != string::npos){
                return true;
            }
            return false;
        }

        void check() {
            if (!isCpp(fileName)) {
                if(isExist(fileName)) {
                    system(("rm -rf " + fileName).c_str());
                }
            }
            else {
                cout << "\033[33m\033[1mThe fileName cant bring subfilename.\033[0m" << endl;
                exit(EXIT_FAILURE);
            }
        }

        void compile() {
            for (auto &s:args){
                if (s[0]=='-') cmd += cmdList[toupper(s[1])];
                if (toupper(s[1])=='D') isDebug = true;
            }
            cmd += " -o " + fileName;
            system(cmd.c_str());
            if (isExist(fileName)) cout << "\033[32m\033[1mCompile Successfully\033[0m" << endl;
            else {
                cout << "\033[31m\033[1mCompile Failed\033[0m" << endl;
                exit(EXIT_FAILURE);
            }
        }

        void run(){
            cout << "\033[32m\033[1mRunning...\033[0m" << endl;
            if (isDebug) {
                system(("gdb " + fileName).c_str());
            }
            else {
                system(("./" + fileName).c_str());
            }
        }

        helper(int argCt, char const *argv[]) {
            // declare variables
            args = vector<string> (argv+2, argv + argCt);
            fileName = string(argv[1]);
            filePath = "./"+ fileName + ".cpp";
            cmd = "g++ " + filePath;

            check();
            compile();
            run();
        }
    private:
        bool isDebug = false;
        vector<string> args;
        string fileName, filePath, cmd;
        map<char, string> cmdList = {
            {'F', " -D DEBUG"}, {'D'," -Wall -g"}
        };
    
};

signed main(int argCt, char const *argv[]){
    //IO;
    #ifdef DEBUG
		freopen("p.in", "r", stdin);
		freopen("p.out", "w", stdout);
	#endif
    helper h(argCt, argv);
    return EXIT_SUCCESS;
}
