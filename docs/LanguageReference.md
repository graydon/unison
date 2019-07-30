# Unison Language Reference

## (Unison version 1.0.M1)

This document is an informal reference for the Unison language, meant as an aid for Unison programmers as well as authors of implementations of the language.

* This language reference, like the language it describes, is a work in progress and will be improved over time ([GitHub link](https://github.com/unisonweb/unison/blob/master/docs/LanguageReference.md)). Contributions and corrections are welcome!

A formal specification of Unison is outside the scope of this document, but links are provided to resources that describe the language’s formal semantics.

## A note on syntax
Unison is a language in which _programs are not text_. That is, the source of truth for a program is not its textual representation as source code, but its structured representation as an abstract syntax tree.

This document describes Unison in terms of its default (and currently, only) textual rendering into source code.

## Top-Level declarations
This section describes the syntactic structure and informal semantics of Unison declarations.

A top-level declaration can appear at the _top level_ or outermost scope of a Unison File. It can be a [term binding](#term-bindings), a [user-defined data type](#user-defined-data-types), or a [user-defined ability](#user-defined-abilities).

### Term Bindings

A Unison term binding consists of an optional [type signature](#type-signature), and a [term definition](#term-definition). For example:

``` haskell
timesTwo : Nat -> Nat
timesTwo x = x * 2
```

The first line in the above is a type signature. The second line is the term definition. The `=` sign splits the definition into a _left-hand side_, which is the term being defined, and the _right-hand side_, which is the definition of the term.

The general form of a term binding is:

``` haskell
name : Type
name p_1 p_2 … p_n = expression
```

`name : Type` is the type signature, where `name` is the name of the term being defined and `Type` is a [type](#unison-types) for that term. The `name` given in the type signature and the `name` given in the definition must be the same.

The parameters `p_1` through `p_n` are the parameters of the function, if any, separated by spaces. The right-hand side of the `=` sign is any [Unison expression](#unison-expressions).

#### Type signature
The type signature `timesTwo : Nat -> Nat` declares that the term named `timesTwo` is a function accepting an argument of type `Nat`  and computes a value of type `Nat`. Type signatures are optional. In the absence of a type signature, Unison will automatically infer the type of a term declaration. If a type signature is present, Unison will verify that the term meets the type given in the signature.

#### Term definition
The left-hand side of the definition consists of the name of the term, followed by argument names (parameters) if the definition is a function. The names of the arguments as well as the name of the term are bound as local variables in the expression on the right-hand side. If the term takes no arguments, the term has the value of the fully evaluated expression on the right-hand side.

The right-hand side of the definition (also known as the _body_) is a [Unison expression](#unison-expressions). The names of the arguments are local variables in this expression, and they are bound to any values passed as arguments to the function when it’s called. The expression in the right-hand side can also refer to the name given to the definition in the left-hand side. In that case, it’s a recursive definition. For example:

``` Haskell
sumUpTo : Nat -> Nat
sumUpTo n = 
  if n < 2 then n 
  else n + sumUpto (drop n 1)
```

The above defines a function `sumUpTo` that recursively sums all the natural numbers (of type `Nat`) less than some number `n`. As an example,  `sumUpTo 3` is `1 + 2 + 3`, which is `6`.

The expression `drop n 1` on line 4 above subtracts one from the natural number `n`.

### User-defined data types

A user-defined data type is introduced with the `type` keyword.

For example:

``` haskell
type Optional a = None | Some a
```

The `=` sign splits the definition into a _left-hand side_ and a _right-hand side_, much like term definitions.

The left-hand side is the data type being defined. It gives a name for the data type and declares a new _type constructor_ with that name (here it’s named `Optional`), followed by names for any type arguments (here there is one and it’s called `a`). These names are bound as type variables in the right-hand side. The right-hand side may also refer to the name given to the type in the left-hand side, in which case it is a recursive type declaration. Note that the fully saturated type construction `Optional Nat` is a type, whereas `Optional` by itself is a type constructor, not a type (it requires a type argument in order to construct a type).

The right-hand side consists of zero or more data constructors separated by `|`. These are _data constructors_ for the type, or ways in which values of the type can be constructed. Each case declares a name for a data constructor (here the data constructors are `None` and `Some`), followed by the **types** of the arguments to the constructor.

When Unison compiles a type definition, it generates a term for each data constructor. Here they are the terms `Some : a -> Optional a`, and `None : Optional a`. It also generates _patterns_ for matching on data 
(see [Pattern Matching](#pattern-matching)).

The general form of a type declaration is as follows:

```
type TypeConstructor p1 p2 … pn 
  = DataConstructor_1
  | DataConstructor_2
  ..
  | DataConstructor_n
```

### User-defined abilities

A user-defined _ability_ declaration has the following general form:

``` haskell
ability A where
  Constructor_1 : Type_1
  Constructor_2 : Type_2
  Constructor_n : Type_n
```

This declares an _ability type constructor_ `A` with data constructors `Constructor_1` through `Constructor_n`.

See [Abilities and Ability Handlers](#abilities-and-ability-handlers) for more on user-defined abilities.

## Unison expressions
This section describes the syntax and informal semantics of Unison expressions.

Unison’s evaluation strategy for expressions is [Applicative Order Call-by-Value](https://en.wikipedia.org/wiki/Evaluation_strategy#Applicative_order). Arguments to functions are evaluated strictly from left to right.

### Identifiers
Unison identifiers come in two flavors:

1. _Regular identifiers_ start with an alphabetic unicode character, emoji (which is any unicode character between 1F400 and 1FAFF inclusive), or underscore (`_`), followed by any number of alphanumeric characters, emoji, or the characters `_`, `!`, or `'`. For example, `foo`, `_bar4`, `qux'`, and `set!` are valid regular identifiers.
2. _Operators_ consist entirely of the characters `!$%^&*-=+<>.~\\/|:`. For example, `+`, `*`, `<>`, and `>>=` are valid operators.

#### Namespace-qualified identifiers
The above describes _unqualified_ identifiers. An identifier can also be _qualified_. A qualified identifier consists of a _qualifier_ or _namespace_, followed by a `.`, followed by either a regular identifier or an operator. The qualifier is one or more regular identifiers separated by `.`. For example `Foo.Bar.baz` is a qualified identifier where `Foo.Bar` is the qualifier.

#### Absolutely qualified identifiers
Namespace-qualified identifiers described above are relative to a “current” namespace, which the programmer can set (and defaults to the root of the global namespace). To ignore the current namespace, an identifier can have an _absolute qualifier_. An absolutely qualified name begins with a `.`. For example, the name `.base.List` always refers to the name `.base.List`, regardless of the current namespace, whereas the name `base.List` will refer to `foo.base.List` if the current namespace is `foo`.

#### Hash-qualified identifiers
Any identifier, including a namespace-qualified one, can appear _hash-qualified_. A hash-qualified identifier has the form `x#h` where `x` is an identifier and `#h` is a _hash literal_. The hash disambiguates names that may refer to more than one thing.

### Reserved words
The following names are reserved by Unison and cannot be used as identifiers: `=`, `:`, `->`, `if`, `then`, `else`, `forall`, `handle`, `in`, `unique`, `where`, `use`, `and`, `or`, `true`, `false`, `type`, `ability`, `alias`, `let`, `namespace`, `case`, `of`, `with`.

### Blocks and statements
A block is an expression that has the general form:

```
statement_1
statement_2
...
statement_n
expression
```

A block can have zero or more statements, and the value of the whole block is the value of the final `expression`. A statement is either: 

1. A _variable binding_ of the form `x = e` where `e` is an expression. This binds the variable `x` to the value of `e` within the scope of the block.
2. An _action_, which is an expression of type `{A} T` for some ability `A` (see [Abilities and Ability Handlers](#abilities-and-ability-handlers)) and some type `T`.

A number of language constructs introduce blocks. These are detailed in the relevant sections of this reference. Wherever Unison expects an expression, a block can be introduced with the  `let` keyword:

```
let <block>
```

Where `<block>` denotes a block as described above.

#### The Lexical Syntax of Blocks
The standard syntax expects statements to appear in a line-oriented layout, where whitespace is significant.

The opening keyword (`let`, `if`, `then`, or `else`, for example) introduces the block, and the position of the first character of the first statement in the block determines the top-left corner of the block. Each statement in the block must be indented to line up with the left edge of the block. The first non-whitespace character that appears to the left of that edge (i.e. outdented) ends the block. Certain keywords also end blocks. For example, `then` ends the block introduced by `if`.

A statement or expression in a block can continue for more than one line as long as each line of the statement is indented further than the first character of the statement or expression.

### Literals
A literal expression is a basic form of Unison expression. Unison has the following types of literals:

* A _natural number_ or _64-bit unsigned integer_ of type `.base.Nat` consists of digits from 0 to 9. The smallest `Nat` is `0` and the largest is `18446744073709551615`.
* A _64-bit signed integer_ of type `.base.Int` consists of a natural number immediately preceded by either `+` or `-`. For example, `4` is a `Nat`, whereas `+4` is an `Int`. The smallest `Int` is `-9223372036854775808` and the largest is `+9223372036854775807`.
* A _64-bit floating point number_ of type `.base.Float` consists of an optional sign (`+`/`-`), followed by two natural numbers separated by `.`. Floating point literals in Unison are [IEEE 754-1985](https://en.wikipedia.org/wiki/IEEE_754-1985) double-precision numbers. For example `1.6777216` is a valid floating point literal.
* A _text literal_ of type `.base.Text` is any sequence of characters between pairs of `"`. The escape character is `\`, so a `"` can be included in a text literal with the escape sequence `\"`. The full list of escape sequences is given in the Escape Sequences section below. For example, `"Hello, World!"` is a text literal. A text literal can span multiple lines, and newlines do not terminate text literals.
* There are two _Boolean literals_: `true` and `false`, and they have type `Boolean`.
* A _hash literal_ begins with the character `#`. See the section **Hashes** for details on the lexical form of hash literals. A hash literal is a reference to a term or type. The type or term that it references must have a definition whose hash digest matches the hash in the literal. The type of a hash literal is the same as the type of its referent. `#abc123e` is an example of a hash literal.
* A _literal list_ has the general form `[v1, v2, ... vn]` where `v1` through `vn` are expressions. A literal list may be empty. For example, `[]`, `[x]`, and `[1,2,3]` are list literals. The expressions that form the elements of the list all must have the same type. If that type is `T`, then the type of the list literal is `.base.List T` or `[T]`.
* A _function literal_ or _lambda_ has the form `p1 p2 ... pn -> e`, where `p1` through `pn` are [regular identifiers](#identifiers) and `e` is a Unison expression (the _body_ of the lambda). The variables `p1` trough `pn` are local variables in `e`, and they are bound to any values passed as arguments to the function when it’s called (see the section [Function Application](#function-application) for details on call semantics). For example `x -> x + 2` is a function literal.
* A _tuple literal_ has the form `(v1,v2, ..., vn)` where `v1` through `vn` are expressions. A value `(a,b)` has type `(A,B)` if `a` has type `A` and `b` has type `B`. A unary tuple `(a)` is identical with the expression `a`. The nullary tuple `()` (pronounced “unit”) is of the trivial type `()` (also pronounced “unit”).

#### Escape sequences
Text literals can include the following escape sequences:

* `\0` = null character
* `\a` = alert (bell)
* `\b` = backspace
* `\f` = form feed
* `\n` = new line
* `\r` = carriage return
* `\t` = horizontal tab
* `\v` = vertical tab
* `\\` = literal `\` character
* `\'` = literal `'` character
* `\"` = literal `"` character

### Comments
A line comment starts with `--` and is followed by any sequence of characters. A line that contains a comment can’t contain anything other than a comment and whitespace. Line comments are currently ignored by Unison.

A line starting with `---` and containing no other characters is a _fold_. Any text below the fold is ignored by Unison.

### Type annotations
A type annotation has the form `e:T` where `e` is an expression and `T` is a type. This tells Unison that `e` is of type `T` (or a subtype of type `T`), and Unison will check that it does. It is a type error for the actual type of `e` to be anything other than a type that conforms to `T`.

### Parenthesized expressions
Any expression can appear in parentheses, and an expression `(e)` is identical with the expression `e`. Parentheses can be used to delimit where an expression begins and ends. For example `(f : P -> Q) y` is an application of the function `f` of type `P -> Q` to the argument `y`. The parentheses are needed to tell Unison that `y` is an argument to `f`, not a part of the type annotation expression.

### Function application
A function application `f a1 a2 an` applies the function `f` to the arguments `a1` through `an`.

The above syntax is valid where `f` is a [regular identifier](#identifiers). If the function name is an operator such as `*`, then the syntax for application isinfix :  `a1 * a2`. Any operator can be used in prefix position by surrounding it in parenthese: `(*) a1 a2`. Any [regular identifier](#identifiers) can be used infix by surrounding it in backticks: ``a1 `f` a2``

All Unison functions are of arity 1. That is, they take exactly one argument. An n-ary function is modeled either as a unary function that returns a further function (a partially applied function) which accepts the rest of the arguments, or as a unary function that accepts a tuple.

Function application associates to the left, so the expression `f a b` is the same as `(f a) b`. If `f` has type `T1 -> T2 -> Tn` then `f a` is well typed only if `a` has type `T1`. The type of `f a` is then `T2 -> Tn`. The type constructor of function types, `->`, associates to the right. So `T1 -> T2 -> Tn` paranthesizes as `T1 -> (T2 -> TN)`. 

The evaluation semantics of function application is applicative order [Call-by-Value](https://en.wikipedia.org/wiki/Evaluation_strategy#Call_by_value). In the expression `f x y`, generally `x` and `y` are fully evaluated in left-to-right order, then `f` is fully evaluated, then `x` and `y` are substituted into the body of `f`, and lastly the body is evaluated. 

An exception to the evaluation semantics is Boolean expressions, which have non-strict semantics.

### Boolean expressions
A Boolean expression has type `Boolean` which has two values, `true` and `false`.

#### Conditional expressions
A _conditional expression_ has the form `if c then t else f`, where `c` is an expression of type `Boolean`, and `t` and `f` are expressions of any type, but `t` and `f` must have the same type.

Evaluation of conditional expressions is non-strict. The evaluation semantics of `if c then t else f` are:
* The condition `c` is always evaluated.
* If `c` evaluates to `true`, the expression `t`  is evaluated and `f` remains unevaluated. The whole expression reduces to the value of `t`.
* If `c` evaluates to `false`, the expression `f` is evaluated and `t` remains unevaluated. The whole expression reduces to the value of `f`.

The keywords `if`, `then`, and `else` each introduce a [Block](bear://x-callback-url/open-note?id=F413131E-1C06-4918-A60E-91F70B3DEFEC-73971-000448D034C2F1CB&header=Blocks%20and%20statements)  as follows:

```
if 
  <block>
then
  <block>
else
  <block>
```

#### Boolean conjunction and disjunction
A _Boolean conjunction expression_ is a `Boolean` expression of the form `and a b` where `a` and `b` are `Boolean` expressions. Note that `and` is not a function, but built-in syntax.

The evaluation semantics of `and a b` are equivalent to `if a then b else false`.

A _Boolean disjunction expression_ is a `Boolean` expression of the form `or a b` where `a` and `b` are `Boolean` expressions. Note that `or` is not a function, but built-in syntax.

The evaluation semantics of `or a b` are equivalent to `if a then true else b`.

### Quoted computations
An expression can appear _quoted_ as `'e`, which is identical with `_ -> e`. If `e` has type `T`, then `'e` has type `() -> T`.

If `c` is a quoted computation, it can be _forced_ with `!c`, which is identical with `c ()`. The expression `c` must have a type `() -> t` for some type `t`, in which case `!c` has type `t`.

### Case expressions and pattern matching
A _case expression_ has the general form:

```
case e of 
  pattern_1 -> block_1
  pattern_2 -> block_2
  ...
  pattern_n -> block_n
```

Where `e` is an expression, called the _scrutinee_ of the case expression.

The evaluation semantics of case expressions are as follows:
1. The scrutinee is evaluated.
2. The first pattern is evaluated and matched against the value of the scrutinee.
3. If the pattern matches, any variables in the pattern are subsituted into the block to the right of its `->` (called the _match body_) and the block is evaluated. Other patterns remain unevaluated. If the pattern doesn’t match then the next pattern is tried and so on.

It is an error if none of the patterns match. In this version of Unison, this error occurs at runtime. In a future version, this should be a compile-time error.

#### Pattern matching
A _pattern_ has one of the following forms:

##### Literal patterns
A _literal pattern_ is a literal `Boolean`, `Nat`, `Int`, `Float`, or `Text`. A literal pattern matches if the scrutinee has that exact value. For example, the pattern `42` matches `Nat` expressions that reduce to `42`.

For example:

``` haskell
case 2 + 2 of
  4 -> "Matches"
  6 -> "Doesn't match"
```

##### Variable patterns
A _variable pattern_ is a [regular identifier](#identifiers) and matches any expression. The expression that it matches will be bound to that identifier as a variable in the match body.

For example, this expression evaluates to `3`:

``` haskell
case 1 + 1 of
  x -> x + 1
```

##### Blank patterns
 A _blank pattern_ has the form `_x` where `x` is a [regular identifier](#identifiers). It matches any expression without creating a variable binding.

For example:

``` haskell
case 42 of
  _ -> "Always matches"
```

##### As-patterns
An _as-pattern_ has the form `v@p` where `v` is a [regular identifier](#identifiers) and `p` is a pattern. This pattern matches if `p` matches, and the variable `v` will be bound in the body to the value matching `p`.

For example, this expression evaluates to `3`:

``` haskell
case 1 + 1 of
  x@4 -> x * 2
  y@2 -> y + 1
```

##### Constructor patterns
A _constructor pattern_ has the form `C p1 p2 ... pn` where `C` is the name of a data constructor in scope, and `p1` through `pn` are patterns such that `n` is the arity of `C`. Note that `n` may be zero. This pattern matches if the scrutinee reduces to a fully applied invocation of the data constructor `C` and the patterns `p1` through `pn` match the arguments to the constructor.

For example, this expression uses `Some` and `None`, the constructors of the `Optional` type, to return the 3rd element of the list `xs` if present or `0` if there was no 3rd element.

``` haskell
case List.at 3 xs of
  None -> 0
  Some x -> x 
```

##### List patterns
A _list pattern_ matches a `List t` for some type `t` and has one of three forms:
	1. `head +: tail` matches a list with at least one element. The pattern `head` is matched against the first element of the list and `tail` is matched against the suffix of the list with the first element removed.
	2. `init :+ last` matches a list with at least one element. The pattern `init` is matched against the prefix of the list with the last element removed, and `last` is matched against the last element of the list.
	3. A _literal list pattern_ has the form `[p1, p2, ... pn]` where `p1` through `pn` are patterns. The patterns `p1` through `pn` are  matched against the elements of the list. This pattern only matches if the length of the scrutinee is the same as the number of elements in the pattern. The pattern `[]` matches the empty list.

Examples:

``` haskell
first : [a] -> Optional a
first as = case as of
  h +: _ -> Some h
  [] -> None

last : [a] -> Optional a
last as = case as of
  _ :+ l -> Some l
  [] -> None

exactlyOne : [a] -> Boolean
exactlyOne a = case a of
  [_] -> true
  _   -> false
```

##### Tuple patterns
 A _tuple pattern_ has the form `(p1, p2, ... pn)` where `p1` through `pn` are patterns. The pattern matches if the scrutinee is a tuple of the same arity as the pattern and `p1` through `pn` match against the elements of the tuple. The pattern `(p)` is identical with the pattern `p`, and the pattern `()` matches the literal value `()` of the trivial type `()` (both pronounced “unit”).

For example, this expression evaluates to `4`:

``` haskell
case (1,2,3) of
  (a,_,c) -> a + c
```

##### Ability patterns
An _ability pattern_ only appears in an _ability handler_ and has one of two forms (see [Abilities and ability handlers](#abilities-and-ability-handlers) for details):
	1. `{C p1 p2 ... pn -> k}` where `C` is the name of an ability constructor in scope, and `p1` through `pn` are patterns such that `n` is the arity of `C`. Note that `n` may be zero. This pattern matches if the scrutinee reduces to a fully applied invocation of the ability constructor `C` and the patterns `p1` through `pn` match the arguments to the constructor.  The scrutinee must be of type `Effect A T` for some ablity `{A}` and type `T`. The variable `k` will be bound to the continuation of the program. If the scrutinee has type `Effect A T` and `C` has type `X ->{A} Y`, then `k` has type `Y -> {A} T`.
	2. `{p}` where `p` is a pattern. This matches the case where the computation is _pure_ (the value of type `Effect A T` calls none of the constructors of the ability `{A}`). A pattern match on an `Effect` is not complete unless this case is handled.

See the section on [abilities and ability handlers](#abilities-and-ability-handlers) for examples of ability patterns.

##### Guard patterns
A _guard pattern_ has the form `p | g` where `p` is a pattern and `g` is a Boolean expression that may reference any variables bound in `p`. The pattern matches if `p` matches and `g` evaluates to `true`.

For example, the following expression evaluates to 6:

``` haskell
case 1 + 2 of
  x | x == 4 -> 0
  x | x + 1 == 4 -> 6
  _ -> 42
```

## Hashes
A _hash_ in Unison is a 512-bit SHA3 digest of a term or a type. The textual representation of a hash is its [base32Hex](https://github.com/multiformats/multibase#multibase-table-v100-rc-semver) Unicode encoding.

Unison attributes a hash to every term and type declaration, and the hash may be used to unambiguously refer to the term or type. As far as Unison is concerned, the hash of a term or type is its _true name_.

### Literal hash references

A term, type, data constructor, or ability constructor may be unambiguously referenced by hash. Literal hash references have the following structure:

* A _built-in reference_ to a Unison built-in term or type `n` has a hash of the form `##n`. `##Nat` is an example of a built-in reference.
* A _term definition_ has a hash of the form `#x` where `x` is the base32Hex encoding of the hash of the term.
* A term or type definition that’s part of a _cycle of mutually recursive definitions_ hashes to the form `#x.n` where `x` is the hash of the cycle and `n` is the term or type’s index in its cycle. A cycle has a canonical order determined by sorting all the members of the cycle by their individual hashes (with the cycle removed).
* A data constructor hashes to the form `#x#c` where `x` is the hash of the data type definition and `c` is the index of that data constructor in the type definition.
* A data constructor in a cyclic type definition hashes to the form `#x.n#c` where `#x.n` is the hash of the data type and `c` is the data constructor’s index in the type definition.

### Short hashes
A hash literal may use a prefix of the base32Hex encoded SHA3 digest instead of the whole thing. For example a short hash like `#r1mtr0` may be used instead of the much longer 104-character representation of the full 512-bit hash.

## Unison types
This section describes informally the structure of types in Unison.

Formally, Unison’s type system is an implementation of the system described by Joshua Dunfield and Neelakantan R. Krishnaswami in their 2013 paper [Complete and Easy Bidirectional Typechecking for Higher-Rank Polymorphism](https://arxiv.org/abs/1306.6032).

Unison extends that type system with, [pattern matching](#pattern-matching), [scoped type variables](#scoped-type-variables), _ability types_ (also known as _algebraic effects_). See the section titled [Abilities and Ability Handlers](#abilities-and-ability-handlers) for details on ability types.

Unison attributes a type to every expression. Types are of the following general forms.

### Type variables
Type variables are [regular identifiers](#identifiers) beginning with a lowercase letter. For example `a`, `x0`, and `foo` are valid type variables.

### Universally quantified types
A _universally quantified type_ has the form `forall v1 v2 vn. t`, where `t` is a type. The type `t` may involve the variables `v1` through `vn`.  

The symbol `∀` is an alias for `forall`.

A type like `forall x. F x` can be written simply as `F x` (the `forall x` is implied) as long as `x` is free in `F x` (it is not bound by an outer scope; see Scoped Type Variables below).

A universally quantified type may be _instantiated_ at any given type. For example, the empty list `[]` has type `forall x. List x`, and it can be instantiated at `Int`, which binds `x` to `Int` resulting in `List Int` which is also a valid type for the empty list.

### Scoped type variables
Type variables introduced by a type signature for a term remain in scope throughout the definition of that term.

For example in the following snippet, the type annotation `temp:x` is telling Unison that `temp` has the type `x` which is bound in the type signature, so `temp` and `a` have the same type.

``` haskell
ex1 : x -> y -> x
ex1 a b =
  -- refers to the type x in the outer scope
  temp : x
  temp = a
  a
```

To explicitly shadow a type variable in scope, the variable can be reintroduced in the inner scope by a `forall` binder, as follows:

``` haskell
ex2 : x -> y -> x
ex2 a b =
  -- doesn’t refer to x in outer scope
  id : ∀ x . x -> x
  id x = x
  id 42
  id a
```

### Type constructors
Just as values are built using data constructors, types are built from _type constructors_. Nullary type constructors like `Nat`, `Int`, `Float` are already types, but other type constructors like `List` and `Tuple` (see [built-in type constructors](#built-in-type-constructors)) take type parameters in order to yield types. `List` is a unary type constructor, so it takes one type (the type of the list elements) . `List Nat` is a type and `Tuple Nat Int` is a type.

#### Kinds of Types
Types are to values as _kinds_ are to type constructors. Unison attributes a kind to every type constructor, which is determined by its number of type parameters and the kinds of those type parameters. Unison’s kinds have the following forms:

* A nullary type constructor or ordinary type has kind `Type`.
* A type constructor has kind `k1 -> k2` where `k1` and `k2` are kinds.

For example `List`, a unary type constructor, has kind `Type -> Type` (it takes a type and yields a type), a binary type constructor like `Tuple` has kind `Type -> Type -> Type` (it takes a type and yields a partially applied unary type constructor). A type constructor of kind `(Type -> Type) -> Type` is a _higher-order_ type constructor (it takes a type constructor and yields a type). 

### Type application
A type constructor is applied to a type or another type constructor, depending on its kind, similarly to how functions are applied to arguments at the term level. `C T` applies the type constructor `C` to the type `T`. Type application associates to the left, so the type `A B C` is identical with the type `(A B) C`.

### Function types
The type `X -> Y` is a type for functions that take arguments of type `X` and yield results of type `Y`. Application of the binary type constructor `->` associates to the right, so the type `X -> Y -> Z` is identical with the type `X -> (Y -> Z)`.

### Tuple types
The type `(A,B)` is a type for binary tuples (pairs) of values, one of type `A` and another of type `B`.  The type `(A,B,C)` is a triple, and so on.

A unary tuple type `(A)` is identical with the type `A`.

The nullary tuple type `()` is the type of the unique value also written `()` and is pronouced “unit”.

In the standard Unison syntax, tuples of arity 2 and higher are actually of a type `Tuple a b` for some types `a` and `b`. For example, `(X,Y)` is syntactic shorthand for the type `Tuple A (Tuple B ())`.

### Built-in types
Unison provides the following built-in types:

* `.base.Nat` is the type of 64-bit natural numbers, also known as unsigned integers. They range from 0 to 18,446,744,073,709,551,615.
* `.base.Int` is the type of 64-bit signed integers. They range from -9,223,372,036,854,775,808 to +9,223,372,036,854,775,807.
* `.base.Float` is the type of [IEEE 754-1985](https://en.wikipedia.org/wiki/IEEE_754-1985) double-precision floating point numbers.
* `.base.Boolean` is the type of Boolean expressions whose value is `true` or `false`.
* `.base.Bytes` is the type of arbitrary-length 8-bit byte sequences.
* `.base.Text` is the type of arbitrary-length strings of Unicode text.
* The trivial type `()` (pronounced “unit”) is the type of the nullary tuple. There is a single data constructor of type `()` and it’s also written `()`.

### Built-in type constructors
Unison has the following built-in type constructors.

* `(->)` is the constructor of function types. A type `X -> Y` is the type of functions from `X` to `Y`. 
*  `base.Tuple` is the constructor of tuple types. A type `Tuple X Y` is the type of pairs of values, one of type `X` and the other of type `Y`. The form `(A,B)` is shorthand for `Tuple A (Tuple B ())`, and `(A,B,C)` is short for `Tuple A (Tuple B (Tuple C ()))` and so on.
* `.base.List` is the constructor of list types. A type `List T` is the type of arbitrary-length sequences of values of type `T`.
* `.base.Request` is the constructor of requests for abilities. A type `Request A T` is the type of values received by ability handlers for the ability `A` where current continuation requires a value of type `T`.

## Abilities and ability handlers
Unison provides a system of _abilities_ and _ability handlers_ as a means of modeling computational effects in a purely functional language. This is based on the Frank language by Sam Lindley, Conor McBride, and Craig McLaughlin (https://arxiv.org/pdf/1611.09259.pdf).

### Abilities in function types

The general form for a function type in Unison is `I ->{A} O`, where `I` is the input type of the function, `O` is the output type, and `A` is the set of _abilities_ that the function requires.

A function type in Unison like `A -> B` is really syntactic sugar for a type `A ->{e} B` where `e` is some set of abilities, possibly empty. A function that definitely requires no abilities has a type like `A ->{} B` (it has an empty set of abilities).

If a function `f` calls in its implementation another function requiring ability set `{A}`, then `f` will require `A` in its ability set as well. If `f` also calls a function requiring abilities `{B}`, then `f` will require abilities `{A,B}`.

Stated the other way around, `f` can only be called in contexts where the abilities `{A,B}` are available. Abilities are provided by `handle` blocks. See the [Ability Handlers](f) section below.

### User-defined abilities

A user-defined ability is declared with an `ability` declaration such as:

``` haskell
ability Store v where
  get : v
  put : v -> ()
```

This results in a new ability type constructor `Store` which takes a type argument `v`. It also create two value-level constructors named `get` and `put`. They have the following types:

* `get : forall v. {Store v} v`
* `put : forall v. v ->{Store v} ()`

The type `{Store v}` means that the computation which results in that type requires a `Store v` ability and cannot be executed except in the context of an _ability handler_ that provides the ability.

### Ability handlers

A constructor `{A} T` for some ability `A` and some type `T`  (or a function which uses such a constructor), can only be used in a scope where the ability `A` is provided. Abilities are provided by `handle` expressions:

``` haskell
handle h in x
```

This expression gives `x` access to abilities handled by the function `h` which must have the type `Request A T -> T` if `x` has type `{A} T`. The type constructor `Request` is a special builtin provided by Unison which will pass arguments of type `Request A T` to a handler for the ability `A`.

#### Pattern matching on ability constructors

Each constructor of an ability corresponds with a _pattern_ that can be used for pattern matching in ability handlers. The general form of such a pattern is:

``` haskell
{A.c p_1 p_2 p_n -> k}
```

Where `A` is the name of the ability, `c` is the name of the constructor, `p_1` through `p_n` are patterns matching the arguments to the constructor, and `k` is a _continuation_ for the program. If the value matching the pattern has type `Request A T` and the constructor of that value had type `X ->{A} Y`, then `k` has type `Y -> {A} T`.

A handler can choose to call the continuation or not. For example, a handler can ignore the continuation in order to handle an ability that aborts the execution of the program:

``` haskell
ability Abort where
  aborting : ()

-- Returns `a` immediately if the program `e` calls `abort`
abortHandler : a -> Effect Abort a -> a
abortHandler a e = case e of 
   { Abort.aborting -> _ } -> a
   { x } -> x

p = handle abortHandler 0 in
  x = 4
  Abort.aborting
  x + 2

```

The program `p` evaluates to `0`. If we remove the `Abort.aborting` call, it evaluates to `6`.

The pattern `{ x }` matches the case where the computation is pure (makes no further requests for the `Abort` ability and the continuation is empty). A pattern match on a `Request` is not complete unless this case is handled.

When a handler calls the continuation, it needs describe how the ability is provided in the rest of the program, usually with a recursive call, like this:

``` haskell
use .base Effect
 
ability Stored v where
  get : v
  put : v -> ()

storeHandler : v -> Effect (Stored v) a -> a
storeHandler storedValue s = case s of 
  {Stored.get -> k} ->
    handle storeHandler storedValue in k storedValue
  {Stored.put v -> k} ->
    handle storeHandler v in k ()
  {a} -> a
```

Note that the `storeHandler` has a `handle` clause that uses `storeHandler` itself to handle the `Requests`s made by the continuation. So it’s a recursive definition.

## Name resolution and the environment
During typechecking, Unison substitutes free variables in an expression by looking them up in a _codebase_. A Unison codebase is a database of term and type definitions, indexed by _hashes_ and names.

A name in the codebase can refer to either terms or types, or both. If a name is unambiguous (refers to only one term or type in the codebase), Unison substitutes that name in the expression with a reference to the definition from the codebase.

A definition in the codebase always refers to other definitions _by hash_, and never by name. Names are stored in the codebase as metadata on the hash, which may have any number of names.

If a free variable in the program cannot be found in the codebase and is not the name of another term in scope in the program itself, or if an free variable matches more than one name (it’s ambiguous), Unison tries _type-directed name resolution_.

### Type-directed name resolution
During typechecking, if Unison encounters a free variable that is not a name in the codebase, Unison attempts _type-directed name resolution_, which:

1. Finds term definitions in the codebase whose _unqualified_ name is the same as the free variable.
2. If exactly one of those terms would make the program typecheck when substituted for the free variable, perform that substitution and resume typechecking.

If name resolution is unable to find the definition of a name, or is unable to disambiguate an ambiguous name, Unison reports an error.