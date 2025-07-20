import numem;
import std.stdio;


class myObject : NuRefCounted {
@nogc:
    ~this() {
        import core.stdc.stdio: printf;
        printf("byebye\n");
    }
};


int main() {
    auto obj = nogc_new!myObject(); 

    obj.release();
    return 0;
}
