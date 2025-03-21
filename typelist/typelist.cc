

template<typename ...T>
struct TypeList;

template<int N, typename T>
struct atN;

template<int N, template <class ...> class T,
         typename Arg0, typename ...Args>
struct atN<N, T<Arg0, Args...>> {
  using Type = typename atN<N-1, T<Args...>>::Type;
};

template<template <class ...> class T,
         typename Arg0, typename ...Args>
struct atN<0, T<Arg0, Args...>> {
  using Type = Arg0;
};

template <typename A, typename TypeList>
struct prependA;

template <template <class ...> class T,
          typename A, typename ...Args>
struct prependA<A, T<Args...>> {
  using Type = T<A, Args...>;
};


template <typename A, typename TypeList>
struct appendA;

template <template <class ...> class T,
          typename A, typename ...Args>
struct appendA<A, T<Args...>> {
  using Type = T<Args..., A>;
};

template <typename T>
struct reverse;

template <template <class ...> class T,
          typename Arg0, typename ...Args>
struct reverse<T<Arg0, Args...>> {
  using Type = typename appendA<Arg0, typename reverse<T<Args...>>::Type>::Type;
};

template <template <class ...> class T,
          typename Arg0>
struct reverse<T<Arg0>> {
  using Type = T<Arg0>;
};


template <typename T>
class TD;

int main() {
  using type = atN<1, TypeList<int, float, double>>::Type;
  TD<type> y;
  //TD<prependA<short, TypeList<int, float>>::Type> y;
  //TD<appendA<short, TypeList<int, float>>::Type> y;
  //TD<reverse<TypeList<int, float, short>>::Type> y;
}
