import std.stdio;

mixin template Gen(T) {
    enum invalid = typeof(this).init;

nothrow @nogc @safe:
    T value = T.init;
    uint validationCounter;

    this(T value, uint validation_counter) {
        this.value = value;
        this.validationCounter = validation_counter;

    }
    alias value this; // can only use to read, like writeln(fd);
}

struct FD { mixin Gen!(int); }

int main() {
    auto fd = FD(1, 2);
    writeln(fd); //alias fd => fd.value
    //fd = 1; //cannot use alias this to partially init FD. as constructor needs two parameters.
    writeln(fd.invalid);
    return 0;
}
