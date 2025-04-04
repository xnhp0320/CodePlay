

template <typename T>
class TD;


template <typename T>
void X(T&& v) {
    TD<T> x;
}


int main() {
    const int i = 1;
    X(i); //T is const int&
}
