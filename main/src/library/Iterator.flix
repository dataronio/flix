/*
 * Copyright 2021 Jakob Schneider Villumsen
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


///
/// The type of the done function.
///
type alias Done = Unit -> Bool & Impure

///
/// The type of the next function.
///
type alias Next[a] = Unit -> a & Impure

///
/// An iterator is a stream of elements that are produced on demand.
///
pub enum Iterator[a] {
    case Iterator(Done, Next[a])
}


namespace Iterator {

    ///
    /// Returns an empty iterator.
    ///
    pub def empty(): Iterator[a] =
        let done = () -> true as & Impure;
        let next = () -> bug!("Empty Iterator!") as & Impure;
        Iterator(done, next)

    ///
    /// Returns an iterator containing only a single element, `x`.
    ///
    pub def singleton(x: a): Iterator[a] & Impure =
        let d = ref false;
        let done = () -> deref d;
        let next = () -> {
            if (done()) {
                bug!("Empty Iterator!")
            }
            else {
                d := true;
                x
            }
        };
        Iterator(done, next)

    ///
    /// Returns `Some(x)` if `iter` is not empty. Returns `None` otherwise.
    ///
    /// Consumes the head element of `iter`.
    ///
    pub def next(iter: Iterator[a]): Option[a] & Impure =
        let Iterator(done, next) = iter;
        if (done())
            None
        else
            Some(next())

    ///
    /// Returns true if the iterator is empty.
    ///
    /// Does **not** consume any elements of the iterator.
    ///
    pub def isEmpty(iter: Iterator[a]): Bool & Impure =
        let Iterator(done, _) = iter;
        done()

    ///
    /// Returns an iterator of all integers between `b` (inclusive) and `e` (exclusive).
    ///
    /// Returns an empty iterator if `b >= e`.
    ///
    @Lazy
    pub def range(b: Int32, e: Int32): Iterator[Int32] & Impure =
        let i = ref b;
        let done = () -> deref i >= e;
        let next = () -> {
                let res = deref i;
                if (res < e) {
                    i := res + 1;
                    res
                }
                else {
                    bug!("Empty Iterator!")
                }
            };
        Iterator(done, next)

    ///
    /// Returns an iterator over an iterable with the element `x` repeated `n` times.
    ///
    /// Returns an empty iterator if `n < 0`.
    ///
    @Lazy
    pub def repeat(n: Int32, x: a): Iterator[a] & Impure =
        let i = ref 0;
        let done = () -> deref i >= n;
        let next = () -> {
              let j = deref i;
              if (j < n) {
                i := j + 1;
                x
              }
              else {
                bug!("Empty Iterator!")
              }
            };
        Iterator(done, next)

    ///
    /// Returns the sum of all elements in the iterator `iter`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def sum(iter: Iterator[Int32]): Int32 & Impure =
        foldLeft((acc, x) -> acc + x, 0, iter)

    ///
    /// Returns the sum of all elements in the iterator `iter` according to the function `f`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def sumWith(f: a -> Int32 & ef, iter: Iterator[a]): Int32 & Impure =
        foldLeft((acc, x) -> acc + f(x), 0, iter)

    ///
    /// Returns the product of all elements in the iterator `iter`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def product(iter: Iterator[Int32]): Int32 & Impure =
        if (isEmpty(iter))
            0
        else
            foldLeft((acc, x) -> acc * x, 1, iter)

    ///
    /// Returns the product of all elements in the iterator `iter` according to the function `f`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def productWith(f: a -> Int32 & ef, iter: Iterator[a]): Int32 & Impure =
        if (isEmpty(iter))
            0
        else
            foldLeft((acc, x) -> acc * f(x), 1, iter)

    ///
    /// Returns an array with the elements of `iter`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def toArray(iter: Iterator[a]): Array[a] & Impure =
        let Iterator(done, next) = iter;
        toArrayAcc(done, next, MutList.new())

    ///
    /// Helper function for `toArray`.
    ///
    def toArrayAcc(done: Done, next: Next[a], v: MutList[a]): Array[a] & Impure =
        if (done()) {
            MutList.toArray(v)
        }
        else {
            MutList.push!(next(), v);
            toArrayAcc(done, next, v)
        }

    ///
    /// Returns the contents of `iter` as a list. Consumes the entire iterator.
    ///
    pub def toList(iter: Iterator[a]): List[a] & Impure =
        let Iterator(done, next) = iter;
        toListAcc(done, next, ks -> ks)

    ///
    /// Helper function for `toList`.
    ///
    def toListAcc(done: Done, next: Next[a], k: List[a] -> List[a]): List[a] & Impure =
        if (done()) {
            k(Nil)
        }
        else {
            let x = next();
            toListAcc(done, next, ks -> k(x :: ks))
        }

    ///
    /// Returns the contents of `iter` as a map. Consumes the entire iterator.
    ///
    pub def toMap(iter: Iterator[(a, b)]): Map[a, b] & Impure with Order[a] =
        let Iterator(done, next) = iter;
        toMapAcc(done, next, Map.empty())

    ///
    /// Helper function for `toMap`.
    ///
    def toMapAcc(done: Done, next: Next[(a, b)], m: Map[a, b]): Map[a, b] & Impure with Order[a] =
        if (done())
            m
        else
            let (k, v) = next();
            toMapAcc(done, next, Map.insert(k, v, m))

    ///
    /// Returns the contents of `iter` as a `Some(Nel)` if `iter` is not empty. Returns None otherwise.
    ///
    pub def toNel(iter: Iterator[a]): Option[Nel[a]] & Impure = match toList(iter) {
        case Nil     => None
        case x :: xs => Some(Nel(x, xs))
    }

    ///
    /// Returns the contents of `iter` as a set. Consumes the entire iterator.
    ///
    pub def toSet(iter: Iterator[a]): Set[a] & Impure with Order[a] =
        let Iterator(done, next) = iter;
        toSetAcc(done, next, Set.empty())

    ///
    /// Helper function for `toSet`.
    ///
    def toSetAcc(done: Done, next: Next[a], s: Set[a]): Set[a] & Impure with Order[a] =
        if (done())
            s
        else
            toSetAcc(done, next, Set.insert(next(), s))

    ///
    /// Returns a list of every element in `iter` that satisfies the predicate `f`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def filter(f: a -> Bool & ef, iter: Iterator[a]): List[a] & Impure =
        let Iterator(done, next) = iter;
        filterAcc(f, done, next, ks -> ks)

    ///
    /// Helper function for `filter`.
    ///
    def filterAcc(f: a -> Bool & ef, done: Done, next: Next[a], k: List[a] -> List[a]): List[a] & Impure =
        if (done())
            k(Nil)
        else
            let x = next();
            let include = f(x);
            if (include) filterAcc(f, done, next, ks -> k(x :: ks)) else filterAcc(f, done, next, k)

    ///
    /// Returns a list with `f` applied to every element in `iter`.
    ///
    /// That is, the result is of the form: `f(x1) :: f(x2) :: ...`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def map(f: a -> b & ef, iter: Iterator[a]): List[b] & Impure =
        let Iterator(done, next) = iter;
        mapAcc(f, done, next, ks -> ks)

    ///
    /// Helper function for `map`.
    ///
    def mapAcc(f: a -> b & ef, done: Done, next: Next[a], k: List[b] -> List[b]): List[b] & Impure =
        if (done())
            k(Nil)
        else
            let x = f(next());
            mapAcc(f, done, next, ks -> k(x :: ks))

    ///
    /// Applies `f` to every element of `iter`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def foreach(f: a -> Unit & ef, iter: Iterator[a]): Unit & Impure =
        let Iterator(done, next) = iter;
        foreachHelper(f, done, next)

    ///
    /// Helper function for `foreach`.
    ///
    def foreachHelper(f: a -> Unit & ef, done: Done, next: Next[a]): Unit & Impure =
        if (done())
            ()
        else
            let _ = f(next());
            foreachHelper(f, done, next)
    ///
    /// Returns an iterator with every element of the iterator `iter` that
    /// satisfies the predicate `f`.
    ///
    /// Does *not* consume any elements from the iterator.
    ///
    /// The original iterator `iter` should not be reused.
    ///
    pub def filterL(f: a -> Bool, iter: Iterator[a]): Iterator[a] & Impure =
        let Iterator(done, next) = iter;

        // Allocate a reference to hold the next element.
        let cursor = ref None;

        let done1 = () -> match deref cursor {
            case None => match forward(f, done, next) {
                case None    => true
                case Some(x) =>
                    // An element was found. Store it in the reference.
                    cursor := Some(x);
                    false
            }
            case Some(_) => false
        };

        let next1 = () -> match deref cursor {
            case None    => bug!("Empty iterator")
            case Some(x) =>
                // An element is in the reference. Use it.
                cursor := None;
                x
        };
        Iterator(done1, next1)

    ///
    /// Fast forwards the given iterator until the next element that satisfies
    /// the given predicate `f`. Returns it (if it exists).
    ///
    def forward(f: a -> Bool & ef, done: Done, next: Next[a]): Option[a] & Impure =
        if (done())
            None
        else {
            let e = next();
            if (f(e)) Some(e) else forward(f, done, next)
        }

    ///
    /// Returns an iterator with every `f` lazily applied to each element in `iter`.
    ///
    /// Does *not* consume any elements from the iterator.
    ///
    pub def mapL(f: a -> b, iter: Iterator[a]): Iterator[b] =
        let Iterator(done, next) = iter;
        let next1 = () -> f(next());
        Iterator(done, next1)

    ///
    /// Returns an iterator with every occurrence of `from` replaced by `to` in `iter`.
    ///
    /// Does *not* consume any elements from the iterator.
    ///
    pub def replace(from: {from :: a}, to: {to :: a}, iter: Iterator[a]): Iterator[a] with Eq[a] =
        let Iterator(done, next) = iter;
        let next1 = () -> {
            let el = next();
            if (el == from.from) to.to else el
        };
        Iterator(done, next1)

    ///
    /// Returns `iterA` appended to `iterB`.
    ///
    /// Does *not* consume any elements from either iterator.
    ///
    /// The original iterators `iterA` and `iterB` should not be reused.
    ///
    pub def append(iterA: Iterator[a], iterB: Iterator[a]): Iterator[a] =
        let Iterator(doneA, nextA) = iterA;
        let Iterator(doneB, nextB) = iterB;
        let doneAB = () -> doneA() and doneB();
        let nextAB = () -> if (doneA()) nextB() else nextA();
        Iterator(doneAB, nextAB)

    ///
    /// Returns an iterator where the element at index `i` is `(a, b)` where
    /// `a` is the element at index `i` in `iterA` and `b` is the element at index `i` in `iterB`.
    ///
    /// Does *not* consume any elements from either iterator.
    ///
    /// If either `iterA` or `iterB` is depleted, then no further elements are added to the resulting iterator.
    ///
    /// The original iterators `iterA` and `iterB` should not be reused.
    ///
    /// An iterator should never be zipped with itself.
    ///
    pub def zip(iterA: Iterator[a], iterB: Iterator[b]): Iterator[(a, b)] =
        let Iterator(doneA, nextA) = iterA;
        let Iterator(doneB, nextB) = iterB;
        let doneAB = () -> doneA() or doneB();
        let nextAB = () -> (nextA(), nextB());
        Iterator(doneAB, nextAB)

    ///
    /// Returns an iterator where the element at index `i` is `f(a, b)` where
    /// `a` is the element at index `i` in `iterA` and `b` is the element at index `i` in `iterB`.
    ///
    /// Does *not* consume any elements from either iterator.
    ///
    /// If either `iterA` or `iterB` becomes depleted, then no further elements are added to the resulting list.
    ///
    /// The original iterators `iterA` and `iterB` should not be reused.
    ///
    /// An iterator should never be zipped with itself.
    ///
    pub def zipWithL(f: (a, b) -> c, iterA: Iterator[a], iterB: Iterator[b]): Iterator[c] =
        let Iterator(done, next) = zip(iterA, iterB);
        let next1 = () -> {
            let (x, y) = next();
            f(x, y)
        };
        Iterator(done, next1)

    ///
    /// Returns an iterator where the element at index `i` is `f(a, b)` where
    /// `a` is the element at index `i` in `iterA` and `b` is the element at index `i` in `iterB`.
    ///
    /// Consumes the entire iterator.
    ///
    /// If either `iterA` or `iterB` becomes depleted, then no further elements are added to the resulting list.
    ///
    /// The original iterators `iterA` and `iterB` should not be reused.
    ///
    /// An iterator should never be zipped with itself.
    ///
    pub def zipWith(f: (a, b) -> c & ef, iterA: Iterator[a], iterB: Iterator[b]): List[c] & Impure =
        zip(iterA, iterB) |> map(xy -> f(fst(xy), snd(xy)))

    ///
    /// Applies `f` to a start value `s` and all elements in `iter` going from left to right.
    ///
    /// That is, the result is of the form: `f(...f(f(s, x1), x2)..., xn)`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def foldLeft(f: (b, a) -> b & ef, s: b, iter: Iterator[a]): b & Impure =
        let Iterator(done, next) = iter;
        foldLeftHelper(f, s, done, next)

    ///
    /// Helper function for `foldLeft`.
    ///
    def foldLeftHelper(f: (b, a) -> b & ef, s: b, done: Done, next: Next[a]): b & Impure =
        if (done())
            s
        else
            foldLeftHelper(f, f(s, next()), done, next)

    ///
    /// Applies `f` to all elements in `iter` going from left to right until a single value `v` is obtained.  Returns `Some(v)`.
    ///
    /// That is, the result is of the form: `Some(f(...f(f(x1, x2), x3)..., xn))`
    ///
    /// Returns `None` if `iter` is empty.
    ///
    /// Consumes the entire iterator.
    ///
    pub def reduceLeft(f: (a, a) -> a & ef, iter: Iterator[a]): Option[a] & Impure =
        let Iterator(done, next) = iter;
        if (done())
            None
        else
            Some(foldLeft(f, next(), iter))

    ///
    /// Returns an iterator over the results of `f`.
    ///
    /// If `f` returns `Ok(x)`, then the next element is `x`.
    ///
    /// If `f` returns `Err(e)`, then the iterator is depleted.
    ///
    pub def unfoldWithOk(f: Unit -> Result[a, b] & ef): Iterator[a] & Impure =
        let cursor = ref None;
        let done = () -> match deref cursor {
            case None    => match f() {
                case Err(_) => true
                case Ok(x)  =>
                    cursor := Some(x);
                    false
            }
            case Some(_) => false
        };
        let next = () -> match deref cursor {
            case None    => bug!("Empty Iterator!")
            case Some(x) =>
                cursor := None;
                x
        };
        Iterator(done, next)

    ///
    /// Returns the longest prefix of `iter` that satisfies the predicate `f`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def takeWhile(f: a -> Bool & ef, iter: Iterator[a]): List[a] & Impure =
        let Iterator(done, next) = iter;
        takeWhileAcc(f, done, next, ks -> ks as & ef) // NB: Cast required because the identity continuation is pure,
                                                      // but the intermediate continuations are effect polymorphic

    ///
    /// Helper function for `takeWhile`.
    ///
    def takeWhileAcc(f: a -> Bool & ef, done: Done, next: Next[a], k: List[a] -> List[a] & ef): List[a] & Impure =
        if (done())
            k(Nil)
        else
            let x = next();
            if (f(x))
                takeWhileAcc(f, done, next, ks -> k(x :: ks))
            else
                k(Nil)

    ///
    /// Returns `iter` without the longest prefix that satisfies the predicate `f`.
    ///
    /// Consumes the entire iterator.
    ///
    pub def dropWhile(f: a -> Bool & ef, iter: Iterator[a]): List[a] & Impure =
        let Iterator(done, next) = iter;
        match forward(x -> not f(x), done, next) {
            case None    => Nil
            case Some(i) => i :: toList(iter)
        }

    ///
    /// Returns the result of applying `f` to every element in `iter` and concatenating the results.
    ///
    /// Does *not* consume any elements from the iterator.
    ///
    pub def flatMap(f: a -> Iterator[b] & ef, iter: Iterator[a]): Iterator[b] & Impure =
        let Iterator(done, next) = iter;
        let cursor = ref None;
        let done1 = () -> match deref cursor {
            case None     => match flatMapForward(f, done, next) {
                case None     => true
                case Some(it) =>
                    cursor := Some(it);
                    false
            }
            case Some(it) =>
                let Iterator(d, _) = it;
                if (d())
                    match flatMapForward(f, done, next) {
                        case None      => true
                        case Some(it1) =>
                            cursor := Some(it1);
                            false
                    }
                else
                    false
        };
        let next1 = () -> match deref cursor {
            case None     => bug!("Empty Iterator!")
            case Some(it) =>
                let Iterator(_, n) = it;
                n()
        };
        Iterator(done1, next1)

    ///
    /// Forwards the given iterator to the first non-empty iterator produced by `f`.
    ///
    def flatMapForward(f: a -> Iterator[b] & ef, done: Done, next: Next[a]): Option[Iterator[b]] & Impure =
        if (done())
            None
        else
            let Iterator(d, n) = f(next());
            if (d()) flatMapForward(f, done, next) else Some(Iterator(d, n))

    ///
    /// Returns an iterator with `a` inserted between every of `iter`.
    ///
    /// Does *not* consume any elements from the iterator.
    ///
    pub def intersperse(x: a, iter: Iterator[a]): Iterator[a] & Impure =
        let Iterator(done, next) = iter;
        let returnX = ref false;
        let next1 = () -> {
            if (deref returnX) {
                returnX := false;
                x
            }
            else {
                returnX := true;
                next()
            }
        };
        Iterator(done, next1)

    ///
    /// Returns the concatenation of the elements in `iterB` with the elements of `iterA` inserted between every two adjacent elements.
    ///
    /// That is, returns `b1 :: a1 ... an :: b2 :: ... bn-1 :: a1 :: ... :: an :: bn :: Nil`.
    ///
    /// Does *not* consume any elements from either iterator.
    ///
    pub def intercalate(iterA: Iterator[a], iterB: Iterator[Iterator[a]]): Iterator[a] & Impure =
        let Iterator(doneA, nextA) = iterA;
        let Iterator(doneB, nextB) = iterB;
        let xs = ref Nil;
        let isReversed = ref false;
        let nextAA = () -> {
            let x = nextA();
            xs := x :: deref xs;
            x
        };
        let doneAA = () -> {
            if (doneA()) {
                if (deref isReversed)
                    ()
                else {
                    xs := List.reverse(deref xs);
                    isReversed := true
                };
                true
            }
            else
                false
        };
        let cursor = ref None;
        let mkCursor = i -> {
            if (deref isReversed)
                // `iterA` has been consumed, so construct a new one from `xs`
                cursor := Some(append(i, List.toIterator(deref xs)))
            else
                cursor := Some(append(i, Iterator(doneAA, nextAA)))
        };
        let done1 = () -> match deref cursor {
            case None    => match intercalateForward(doneB, nextB) {
                case None    => true
                case Some(i) =>
                    if (doneB())
                        cursor := Some(i)
                    else
                        mkCursor(i);
                    false
            }
            case Some(i) =>
                let Iterator(d, _) = i;
                if (d()) match intercalateForward(doneB, nextB) {
                    case None    => true
                    case Some(i) =>
                        if (doneB())
                            cursor := Some(i)
                        else
                            mkCursor(i);
                        false
                }
                else
                    false
        };
        let next1 = () -> match deref cursor {
            case None    => bug!("Empty Iterator!")
            case Some(i) =>
                let Iterator(_, n) = i;
                n()
        };
        Iterator(done1, next1)

    ///
    /// Forwards the iterator the first non-empty iterator produced by `next`.
    ///
    def intercalateForward(done: Done, next: Next[Iterator[a]]): Option[Iterator[a]] & Impure =
        if (done())
            None
        else
            let Iterator(d, n) = next();
            if (d()) intercalateForward(done, next) else Some(Iterator(d, n))

    ///
    /// Returns the concatenation of the string representation
    /// of each element in `iter` with `sep` inserted between each element.
    ///
    /// Consumes the entire iterator.
    ///
    pub def join(sep: String, iter: Iterator[a]): String & Impure with ToString[a] =
        joinWith(x -> ToString.toString(x), sep, iter)

    ///
    /// Returns the concatenation of the string representation
    /// of each element in `iter` according to `f` with `sep` inserted between each element.
    ///
    /// Consumes the entire iterator.
    ///
    pub def joinWith(f: a -> String & ef, sep: String, iter: Iterator[a]): String & Impure =
        use StringBuilder.append!;
        let lastSep = String.length(sep);
        let sb = StringBuilder.new();
        foldLeft((_, x) -> { append!(sb, f(x)); append!(sb, sep) }, (), iter);
        StringBuilder.toString(sb) |> String.dropRight(lastSep)

}
