/*!
\title{KOOL --- Typed --- Dynamic}
\author{Grigore Ro\c{s}u and Traian Florin \c{S}erb\u{a}nu\c{t}\u{a}
        (\texttt{\{grosu,tserban2\}@illinois.edu})}
\organization{University of Illinois at Urbana-Champaign}
*/

/*@
\section{Abstract}
This is the \K dynamic semantics of the typed KOOL language.  It is
very similar to the semantics of the untyped KOOL, the difference
being that we now check the typing policy dynamically.  Since we have
to now declare the types of variables and methods, we adopt a syntax
for those which is close to Java.  Like in the semantics of
untyped KOOL, where we borrowed almost all the semantics of untyped
SIMPLE, we are going to also borrow much of the semantics of
dynamically typed SIMPLE here.  We will highlight the differences
between the dynamically typed and the untyped KOOL as we proceed with
the semantics.  In general, the type policy of the typed KOOL language
is similar to that of Java.  You may find it useful to also read
the discussion in the preamble of the static semantics of typed KOOL
before proceeding. */

module KOOL-TYPED-DYNAMIC-SYNTAX

/*@ \section{Syntax}

Like for the untyped KOOL language, the syntax of typed KOOL extends
that of typed SIMPLE with object-oriented constructs.
The syntax below was produced by copying and modifying/extending the
syntax of dynamically typed SIMPLE.  In fact, the only change we made
to the existing syntax of dynamically typed SIMPLE was to change the
strictness of the application construct like in untyped KOOL, from
\texttt{strict} to \texttt{strict(2)} (because application is not
strict in the first argument anymore due to dynamic method dispatch).
The KOOL-specific syntactic extensions are identical to those in
untyped KOOL.  */

  syntax Id ::= "Object" | "Main"

//@ \subsection{Types}

  syntax Type ::= "void" | "int" | "bool" | "string"
                | Id                              // KOOL class
                | Type "[" "]"
                > Types "->" Type
                | "(" Type ")"           [bracket]
  syntax Types ::= List{Type,","}

//@ \subsection{Declarations}

  syntax Param ::= Type Id
  syntax Params ::= List{Param,","}

  syntax Decl ::= Type Exps ";" [avoid]
                | Type Id "(" Params ")" Block    // stays like in typed SIMPLE
                | "class" Id Block                // KOOL
                | "class" Id "extends" Id Block   // KOOL

//@ \subsection{Expressions}

  syntax Exp ::= Int | Bool | String | Id
               | "this"                                 // KOOL
               | "super"                                // KOOL
               | "(" Exp ")"             [bracket]
               | "++" Exp
               | Exp "instanceOf" Id     [strict(1)]    // KOOL
               | "(" Id ")" Exp          [strict(2)]    // KOOL  cast
               | "new" Id "(" Exps ")"   [strict(2)]    // KOOL
               | Exp "." Id                             // KOOL
               > Exp "[" Exps "]"        [strict]
               > Exp "(" Exps ")"        [strict(2)]    // was strict in SIMPLE
               | "-" Exp                 [strict]
               | "sizeOf" "(" Exp ")"    [strict]
               | "read" "(" ")"
               > left:
                 Exp "*" Exp             [strict, left]
               | Exp "/" Exp             [strict, left]
               | Exp "%" Exp             [strict, left]
               > left:
                 Exp "+" Exp             [strict, left]
               | Exp "-" Exp             [strict, left]
               > non-assoc:
                 Exp "<" Exp             [strict, non-assoc]
               | Exp "<=" Exp            [strict, non-assoc]
               | Exp ">" Exp             [strict, non-assoc]
               | Exp ">=" Exp            [strict, non-assoc]
               | Exp "==" Exp            [strict, non-assoc]
               | Exp "!=" Exp            [strict, non-assoc]
               > "!" Exp                 [strict]
               > left:
                 Exp "&&" Exp            [strict(1), left]
               | Exp "||" Exp            [strict(1), left]
               > "spawn" Block
               > Exp "=" Exp             [strict(2), right]

  syntax Exps ::= List{Exp,","}          [strict]

//@ \subsection{Statements}

  syntax Block ::= "{" "}"
                | "{" Stmts "}"

  syntax Stmt ::= Decl | Block
                | Exp ";"                               [strict]
                | "if" "(" Exp ")" Block "else" Block   [avoid, strict(1)]
                | "if" "(" Exp ")" Block
                | "while" "(" Exp ")" Block
                | "for" "(" Stmt Exp ";" Exp ")" Block
                | "print" "(" Exps ")" ";"              [strict]
                | "return" Exp ";"                      [strict]
                | "return" ";"
                | "try" Block "catch" "(" Param ")" Block
                | "throw" Exp ";"                       [strict]
                | "join" Exp ";"                        [strict]
                | "acquire" Exp ";"                     [strict]
                | "release" Exp ";"                     [strict]
                | "rendezvous" Exp ";"                  [strict]

  syntax Stmts ::= Stmt
                 | Stmts Stmts                          [right]

//@ \subsection{Desugaring macros}

  rule if (E) S => if (E) S else {}                                     [macro]
  rule for(Start Cond; Step) {S:Stmts} => {Start while(Cond){S Step;}}  [macro]
  rule T:Type E1:Exp, E2:Exp, Es:Exps; => T E1; T E2, Es;               [macro]
  rule T:Type X:Id = E; => T X; X = E;                                  [macro]

  rule class C:Id S => class C extends Object S                     // KOOL

endmodule


/*@ \section{Semantics}
We first discuss the new configuration, then we include the semantics of
the constructs borrowed from SIMPLE which stay unchanged, then those
whose semantics had to change, and finally the semantics of the
KOOL-specific constructs.  */

module KOOL-TYPED-DYNAMIC
  imports KOOL-TYPED-DYNAMIC-SYNTAX

/*@ \subsection{Configuration}
The configuration of dynamically typed KOOL is almost identical to
that of its untyped variant.  The only difference is the cell
\textsf{return}, inside the \textsf{control} cell, whose role is to
hold the expected return type of the invoked method.  That is because
we want to dynamically check that the value that a method returns has
the expected type. */

  configuration <T color="red">
                  <threads color="orange">
                    <thread multiplicity="*" color="yellow">
                      <k color="green"> ($PGM:Stmts ~> execute) </k>
                      <br/>
                      <control color="cyan">
                        <fstack color="blue"> .List </fstack>
                        <xstack color="purple"> .List </xstack>
                        <return color="LimeGreen"> void </return>  // KOOL
                        <br/>
                        <crntObj color="Fuchsia">  // KOOL
                           <crntClass> Object </crntClass>
                           <envStack> .List </envStack>
                           <location multiplicity="?"> .K </location>
                        </crntObj>
                      </control>
                      <br/>
                      <env color="violet"> .Map </env>
                      <holds color="black"> .Map </holds>
                      <id color="pink"> 0 </id>
                    </thread>
                  </threads>
                  <br/>
                  <store color="white"> .Map </store>
                  <busy color="cyan">.Set </busy>
                  <terminated color="red"> .Set </terminated>
                  <in color="magenta" stream="stdin"> .List </in>
                  <out color="brown" stream="stdout"> .List </out>
                  <nextLoc color="gray"> 0 </nextLoc>
                  <br/>
                  <classes color="Fuchsia">        // KOOL
                     <class multiplicity="*" color="Fuchsia">
                        <className color="Fuchsia"> Main </className>
                        <extends color="Fuchsia"> Object </extends>
                        <declarations color="Fuchsia"> .K </declarations>
                     </class>
                  </classes>


                  <cfg>
                    <method multiplicity="*">
                        <classContainer>.K</classContainer>
                        <methodName>.K</methodName>
                        <graph>.Map</graph>
                    </method>
                  </cfg>
                  <currentMethod> .K </currentMethod>
                  <currentClass> .K </currentClass>
                  <buffer>
                      <block> .K </block>
                      <prevNodes> .List </prevNodes>
                      <bufferstack> .List </bufferstack>
                  </buffer>
                </T>

/*@ \subsection{Unchanged semantics from dynamically typed SIMPLE}

The semantics below is taken over from dynamically typed SIMPLE
unchanged.  Like for untyped KOOL, the semantics of function/method
declaration and invocation, and of program initialization needs to
change.  Moreover, due to subtyping, the semantics of several imported
SIMPLE constructs can be made more general, such as that of the
return statement, that of the assignment, and that of the exceptions.
We removed all these from the imported semantics of SIMPLE below and
gave their modified semantics right after, together with the extended
semantics of thread spawning (which is identical to that of untyped
KOOL).  */

  syntax Val ::= Int | Bool | String
               | array(Type,Int,Int)
  syntax Vals ::= List{Val,","}
  syntax Exp ::= Val
  syntax KResult ::= Val


  syntax K ::= undefined(Type)  [latex(\bot_{#1})]

  rule <k> T:Type X:Id; => . ...</k>
       <env> Env => Env[L/X] </env>
       <store>... . => L |-> undefined(T) ...</store>
       <nextLoc> L:Int => L +Int 1 </nextLoc>


  rule <k> T:Type X:Id[N:Int]; => . ...</k>
       <env> Env => Env[L/X] </env>
       <store>... . => L |-> array(T, L +Int 1, N)
                       (L +Int 1)...(L +Int N) |-> undefined(T) ...</store>
       <nextLoc> L:Int => L +Int 1 +Int N </nextLoc>
    when N >=Int 0

  context _:Type _::Exp[HOLE::Exps];


  syntax Id ::= "$1" | "$2"
  rule T:Type X:Id[N1:Int, N2:Int, Vs:Vals];
    => T[]<Vs> X[N1];
       {
         T[][]<Vs> $1=X;
         for(int $2=0; $2 <= N1 - 1; ++$2) {
           T X[N2,Vs];
           $1[$2] = X;
         }
       }
    [structural]


  rule <k> X:Id => V ...</k>
       <env>... X |-> L ...</env>
       <store>... L |-> V:Val ...</store>  [lookup]


  context ++(HOLE => lvalue(HOLE))
  rule <k> ++loc(L) => I +Int 1 ...</k>
       <store>... L |-> (I:Int => I +Int 1) ...</store>  [increment]


  rule I1:Int + I2:Int => I1 +Int I2
  rule Str1:String + Str2:String => Str1 +String Str2
  rule I1:Int - I2:Int => I1 -Int I2
  rule I1:Int * I2:Int => I1 *Int I2
  rule I1:Int / I2:Int => I1 /Int I2 when I2 =/=K 0
  rule I1:Int % I2:Int => I1 %Int I2 when I2 =/=K 0
  rule - I:Int => 0 -Int I
  rule I1:Int < I2:Int => I1 <Int I2
  rule I1:Int <= I2:Int => I1 <=Int I2
  rule I1:Int > I2:Int => I1 >Int I2
  rule I1:Int >= I2:Int => I1 >=Int I2
  rule V1:Val == V2:Val => V1 ==K V2
  rule V1:Val != V2:Val => V1 =/=K V2
  rule ! T:Bool => notBool(T)
  rule true  && E => E
  rule false && _ => false
  rule true  || _ => true
  rule false || E => E


  rule V:Val[N1:Int, N2:Int, Vs:Vals] => V[N1][N2, Vs]
    [structural, anywhere]

  rule array(_:Type, L:Int, M:Int)[N:Int] => lookup(L +Int N)
    when N >=Int 0 andBool N <Int M  [structural, anywhere]

  rule sizeOf(array(_,_,N)) => N


  syntax Val ::= nothing(Type)
  rule <k> return; => return nothing(T); ...</k> <return> T </return>
    [structural]


  rule <k> read() => I ...</k> <in> ListItem(I:Int) => . ...</in>  [read]


  context (HOLE => lvalue(HOLE)) = _


  rule {} => .  [structural]
  rule <k> { S } => S ~> env(Env) ...</k>  <env> Env </env>  [structural]


  rule S1:Stmts S2:Stmts => S1 ~> S2  [structural]


  rule _:Val; => .


  rule if ( true) S else _ => S
  rule if (false) _ else S => S


  rule while (E) S => if (E) {S while(E)S}  [structural]


  rule <k> print(V:Val, Es => Es); ...</k> <out>... . => ListItem(V) </out>
    when typeOf(V) ==K int orBool typeOf(V) ==K string  [print]
  rule print(.Vals); => .  [structural]


  rule (<thread>... <k>.</k> <holds>H</holds> <id>T</id> ...</thread> => .)
       <busy> Busy => Busy -Set keys(H) </busy>
       <terminated>... . => SetItem(T) ...</terminated>

  rule <k> join T:Int; => . ...</k>
       <terminated>... SetItem(T) ...</terminated>

  rule <k> acquire V:Val; => . ...</k>
       <holds>... . => V |-> 0 ...</holds>
       <busy> Busy (. => SetItem(V)) </busy>
    when (notBool(V in Busy:Set))  [acquire]

  rule <k> acquire V; => . ...</k>
       <holds>... V:Val |-> (N:Int => N +Int 1) ...</holds>

  rule <k> release V:Val; => . ...</k>
       <holds>... V |-> (N => N:Int -Int 1) ...</holds>
    when N >Int 0

  rule <k> release V; => . ...</k> <holds>... V:Val |-> 0 => . ...</holds>
       <busy>... SetItem(V) => . ...</busy>

  rule <k> rendezvous V:Val; => . ...</k>
       <k> rendezvous V; => . ...</k>  [rendezvous]

//@\subsubsection{Unchanged auxiliary operations from dynamically typed SIMPLE}

  syntax Decl ::= mkDecls(Params,Vals)  [function]
  rule mkDecls((T:Type X:Id, Ps:Params), (V:Val, Vs:Vals))
    => T X=V; mkDecls(Ps,Vs)
  rule mkDecls(.Params,.Vals) => {}

  syntax K ::= lookup(Int)
  rule <k> lookup(L) => V ...</k> <store>... L |-> V:Val ...</store>  [lookup]

  syntax K ::= env(Map)
  rule <k> env(Env) => . ...</k>  <env> _ => Env </env>  [structural]
  rule (env(_) => .) ~> env(_)  [structural]

  syntax Exp ::= lvalue(K)
  syntax Val ::= loc(Int)
  rule <k> lvalue(X:Id => loc(L)) ...</k>  <env>... X |-> L:Int ...</env>
    [structural]

  context lvalue(_::Exp[HOLE::Exps])
  context lvalue(HOLE::Exp[_::Exps])

  rule lvalue(lookup(L:Int) => loc(L))  [structural]

  syntax Type ::= Type "<" Vals ">"  [function]
  rule T:Type<_,Vs:Vals> => T[]<Vs>
  rule T:Type<.Vals> => T

  syntax Map ::= Int "..." Int "|->" K
    [function, latex({#1}\ldots{#2}\mapsto{#3})]
  rule N...M |-> _ => .Map  when N >Int M
  rule N...M |-> K => N |-> K (N +Int 1)...M |-> K  when N <=Int M

  syntax Type ::= typeOf(K)  [function]
  rule typeOf(_:Int) => int
  rule typeOf(_:Bool) => bool
  rule typeOf(_:String) => string
  rule typeOf(array(T,_,_)) => (T[])
  rule typeOf(undefined(T)) => T
  rule typeOf(nothing(T)) => T

  syntax Types ::= getTypes(Params)  [function]
  rule getTypes(T:Type _:Id) => T, .Types
  rule getTypes(T:Type _:Id, P, Ps) => T, getTypes(P,Ps)
  rule getTypes(.Params) => void, .Types


/*@ \subsection{Changes to the existing dynamically typed SIMPLE semantics}

We extend/change the semantics of several SIMPLE constructs in order
to take advantage of the richer KOOL semantic infrastructure and thus
get more from the existing SIMPLE constructs. */


/*@ \subsubsection{Program initialization}

Like in untyped KOOL. */

  syntax K ::= "execute"
  rule <k> execute => new Main(.Exps); </k> <env> . </env>  [structural]


/*@ \subsubsection{Method application}

The only change to untyped KOOL's values is that method closures are
now typed (their first argument holds their type): */

 syntax Val ::= objectClosure(CrntObjCellFragment)
              | methodClosure(Type,Id,Int,Params,Stmt)

/*@ The type held by a method clossure will be the entire type of the
method, not only its result type like the lambda-closure of typed
SIMPLE.  The reason for this change comes from the the need to
dynamically upcast values when passed to contexts where values of
superclass types are expected; since we want method closures to be
first-class-citizen values in our language, we have to be able to
dynamically upcast them, and in order to do that elegantly it is
convenient to store the entire ``current type'' of the method closure
instead of just its result type.  Note that this was unnecessary in
the semantics of the dynamically typed SIMPLE language. */

/*@ Method closure application needs to also set a new return type in
the \textsf{return} cell, like in dynamically typed SIMPLE, in order
for the values returned by its body to be checked against the return
type of the method.  To do this correctly, we also need to stack the
current status of the \textsf{return} cell and then pop it when the
method returns.  We have to do the same with the current object
environment, so we group them together in the stack frame.  */

  syntax K ::=  (Map,K,ControlCellFragment)

  rule <k> methodClosure(_->T,Class,OL,Ps,S)(Vs:Vals) ~> K
           => mkDecls(Ps,Vs) S return; </k>
       <env> Env => . </env>
       <store>... OL |-> objectClosure(<crntClass>_</crntClass> Obj)...</store>
       <br/>
       <control>
          C
          <fstack> . => ListItem((Env, K, C <crntObj> Obj' </crntObj>
                                   <return> T' </return>)) ...</fstack>
          <crntObj> Obj' => <crntClass> Class </crntClass> Obj </crntObj>
          <return> T' => T </return>
       </control>

/*@ At method return, we have to check that the type of the returned
value is a subtype of the expected return type.  Moreover, if that is
the case, then we also upcast the returned value to one of the
expected type.  The computation item \texttt{unsafeCast(V,T)} changes
the typeof $V$ to $T$ without any additional checks; however, it only
does it when $V$ is an object or a method, otherwise it returns $V$
unchanged.  */

  rule <k> return V:Val; ~> _
           => subtype(typeOf(V), T) ~> true? ~> unsafeCast(V, T) ~> K
       </k>
       <control>
         <fstack> ListItem((Env, K, C)) => . ...</fstack>
         (<return> T:Type </return> _ => C)
       </control>
       <env> _ => Env </env>


/*@ \subsubsection{Assignment}

Typed KOOL allows to assign subtype instance values to supertype
lvalues.  The semantics of assignment below is similar in spirit to
dynamically typed SIMPLE's, but a check is performed that the assigned
value's type is a subtype of the location's type.  If that is the
case, then the assigned value is returned as a result and stored, but
it is upcast appropriately first, so the context will continue to see
a value of the expected type of the location.  Note that the type of a
location is implicit in the type of its contents and it never changes
during the execution of a program; its type is assigned when the
location is allocated and initialized, and then only type-preserving
values are allowed to be stored in each location.  */

  rule <k> loc(L) = V:Val
           => subtype(typeOf(V),typeOf(V')) ~> true?
              ~> unsafeCast(V, typeOf(V')) ...</k>
       <store>... L |-> (V' => unsafeCast(V, typeOf(V'))) ...</store>
    [assignment]


/*@ \subsubsection{Typed exceptions}

Exceptions are propagated now until a catch that can handle them is
encountered. */

  syntax K ::= (Param,Stmt,K,Map,ControlCellFragment)
  syntax K ::= "popx"

  rule <k> (try S1 catch(P) S2 => S1 ~> popx) ~> K </k>
       <control>
         <xstack> . => ListItem((P, S2, K, Env, C)) ...</xstack>
         C
       </control>
       <env> Env </env>

  rule <k> popx => . ...</k>
       <xstack> _:ListItem => . ...</xstack>

  rule <k> throw V:Val; ~> _
        => if (subtype(typeOf(V),T)) { T X = V; S2 } else { throw V; } ~> K
       </k>
       <control>
         <xstack> ListItem((T:Type X:Id, S2, K, Env, C)) => . ...</xstack>
         (_ => C)
       </control>
       <env> _ => Env </env>


/*@ \subsubsection{Spawn}

Like in untyped KOOL. */

  rule <thread>...
         <k> spawn S => T ...</k>
         <env> Env </env>
         <crntObj> Obj </crntObj>
       ...</thread>
       (. => <thread>...
               <k> S </k>
               <env> Env </env>
               <id> T </id>
               <crntObj> Obj </crntObj>
             ...</thread>)
    when fresh(T:Int)


//@ \subsection{Semantics of the new KOOL constructs}

/*@ \subsubsection{Class declaration}

/*@ \subsubsection{Control Flow Generator}
Like in untyped KOOL. */

  rule <k> class Class1 extends Class2 { S } => generateFlow(S)  ...</k>
       <currentClass> _ => Class1 </currentClass>
       <classes>... (. => <class>
                            <className> Class1 </className>
                            <extends> Class2 </extends>
                            <declarations> S </declarations>
                        </class>)
       ...</classes>  [structural]

  // rule <block> for(Start Cond; Step) {S:Stmts} => Start while(Cond){S Step;} ... </block> [macro]


  syntax K ::=  (BufferCellFragment)  
  syntax K ::= generateFlow(Stmts)
  syntax Stmt ::= "startFlow" | "exitFlow"
  syntax K ::= newBlock(Stmt, Stmts)  
  syntax K ::= "pushBlock2Stack" 
  syntax K ::= "erasePrevNodes"
  syntax K ::= generateBlock(Stmt, Stmts)  
  syntax K ::= "generatingFlow"     
  syntax K ::= addToFlow(Stmt)     

  syntax K ::= changeBlock(Stmt, Stmt, Stmts) 
  syntax K ::= connectBlocks(Stmt, Stmt)    
  syntax K ::= "connect2Exit"

  rule <k> generateFlow(S1:Stmts S2:Stmts) => generateFlow(S1) ~> generateFlow(S2) ...</k> [structural]

// pass over the class fields 
  rule <k> generateFlow(T:Type E:Exps;) => . ...</k> [structural]

  rule <k> generateFlow(T:Type F:Id(Ps:Params) { S }) => newBlock(startFlow,  S) ~> "connect2Exit" ... </k> 
       <currentMethod> _ => F </currentMethod>
       <currentClass> C </currentClass> 
       <cfg>... . => 
          <method> 
            <classContainer> C </classContainer> 
            <methodName> F </methodName> 
            <graph> .Map </graph> 
          </method> 
       </cfg>
       <bufferstack> _ => . </bufferstack>

  rule <k> newBlock(PrevNode:Stmt, All:Stmts) =>  "pushBlock2Stack" ~> generateBlock(PrevNode, All) ...</k>

  rule <k> generateBlock(PrevNode:Stmt, All:Stmts)  => "generatingFlow" ...</k>
       <buffer>
          <block> _ => All </block>
          <prevNodes> _ => ListItem(PrevNode) </prevNodes>
          ...
       </buffer>

// store previous block in a stack
  rule <k> "pushBlock2Stack" => . ...</k>
       <buffer>
          Rest 
          <bufferstack>. => ListItem((Rest)) ...</bufferstack>
       </buffer>
  rule <k> "erasePrevNodes" => . ...</k>
       <prevNodes> _ => . </prevNodes>


  rule <k> "generatingFlow" ...</k>
       <block> {S} => S ...</block>

       
  rule <k> "generatingFlow" => addToFlow(E;) ~> "erasePrevNodes" ~> newBlock(E; ,Block1) ~> newBlock(E; , Block2) ~> "generatingFlow" ...</k>
       <block> if ( E:Exp ) {Block1:Stmts} else {Block2:Stmts} => .  ...</block>

  rule <k> "generatingFlow" => addToFlow(E;) ~> "erasePrevNodes" ~> newBlock(E; ,Block1) ~> "generatingFlow" ...</k>
       <block> if ( E:Exp ) {Block1:Stmts} else {} => .  ...</block>

  rule <k> "generatingFlow" => addToFlow(E;) ~> "erasePrevNodes" ~> newBlock(E; ,Block1) ~> "generatingFlow" ...</k>
       <block> while ( E:Exp ) {Block1:Stmts} => E;  ...</block>

// // Connecting all prev nodes to stmt!
  rule <k> "generatingFlow" => addToFlow(S) ~> "generatingFlow" ...</k>
       <block> S:Stmt => . ...</block>
       <prevNodes>... ListItem(_)</prevNodes>



  rule <k> addToFlow(S:Stmt) ...</k>
       <currentClass> C </currentClass>
       <currentMethod> F </currentMethod>
       <buffer>
            <prevNodes>... ListItem(PreviousStmt) => .</prevNodes>
            ... 
       </buffer>
       <method>
            <classContainer> C </classContainer>
            <methodName> F </methodName> 
            <graph>... . => PreviousStmt |-> S </graph>
       </method>       
 
 // After connecting all prev nodes to stmt, lets proceed by putting stmt as a prev node. 
  rule <k> addToFlow(S:Stmt) => . ...</k>
       <prevNodes> . => ListItem(S) </prevNodes>

  rule <k> "generatingFlow" ...</k>
       <block> .K</block>
       <prevNodes>... ListItem(PreviousStmt) => . </prevNodes>
       <bufferstack> ListItem((<prevNodes>... . => ListItem(PreviousStmt) </prevNodes> _)) _ </bufferstack>
  
    rule <k> "generatingFlow" => "recoverPreviousBlock" ...</k>
       <block> .K</block>
       <prevNodes> .List </prevNodes>
  
  rule <k> "recoverPreviousBlock" => . ...</k>
       <buffer>
          (_ => Rest) 
          <bufferstack> ListItem((Rest)) => . ...</bufferstack>
       </buffer>

  rule <k> "connect2Exit" ...</k>
       <currentMethod> F </currentMethod>
       <currentClass> C </currentClass>
       <buffer>
            <block> .K</block>
            <prevNodes> ... ListItem(ExitStmt) => .</prevNodes>
            ...
       </buffer>
       <method>
        <classContainer> C </classContainer>
        <methodName> F </methodName> 
        <graph>... . => ExitStmt |-> exitFlow </graph>
       </method>

  rule <k> "connect2Exit" => . ...</k>
       <block> .K</block>
       <prevNodes> .List </prevNodes> 
       

  rule <block> S1:Stmts S2:Stmts => S1 ~> S2  ...</block> [structural]



/*@ \subsubsection{Method declaration}

Methods are now typed and we need to store their types in their
closures, so that their type contract can be checked at invocation
time.  The rule below is conceptually similar to that of untyped KOOL;
the only difference is the addition of the types. */

  rule <k> T:Type F:Id(Ps:Params) S => . ...</k>
       <crntClass> C </crntClass>
       <location> OL </location>
       <env> Env => Env[L/F] </env>
       <store>... . => L|->methodClosure(getTypes(Ps)->T,C,OL,Ps,S) ...</store>
       <nextLoc> L => L +Int 1 </nextLoc>


/*@ \subsubsection{New}

The semantics of \texttt{new} in dynamically typed KOOL is also
similar to that in untyped KOOL, the main difference being the
management of the return types.  Indeed, when a new object is created
we also have to stack the current type in the \textsf{return} cell in
order to be recovered after the creation of the new object.  Only the
first rule below needs to be changed; the others are identical to
those in untyped KOOL. */

  syntax K ::= (Id,EnvCellSort)

  rule <k> new Class:Id(Vs:Vals) ~> K
           => create(Class) ~> (storeObj ~> ((Class(Vs)); return this;)) </k>
       <env> Env => . </env>
       <nextLoc> L:Int => L +Int 1 </nextLoc>
       <br/>
       <control> C
         <crntObj> Obj
                   => <crntClass> Object </crntClass>
                      <envStack> ListItem((Object, <env>.Map</env>)) </envStack>
                      <location> L </location>
         </crntObj>
         <return> T => Class </return>
         <fstack> . => ListItem((Env, K, C <return>T</return> <crntObj>Obj</crntObj>))
         ...</fstack>
       </control>

  syntax K ::= create(Id)

  rule <k> create(Class:Id)
           => create(Class1) ~> setCrntClass(Class) ~> S ~> addEnvLayer ...</k>
       <className> Class </className>
       <extends> Class1:Id </extends>
       <declarations> S </declarations>  [structural]

  rule <k> create(Object) => . ...</k>  [structural]

  syntax K ::= setCrntClass(Id)

  rule <k> setCrntClass(C) => . ...</k>
       <crntClass> _ => C </crntClass>  [structural]

  syntax K ::= "addEnvLayer"

  rule <k> addEnvLayer => . ...</k>
       <env> Env => . </env>
       <crntClass> Class:Id </crntClass>
       <envStack> . => ListItem((Class, <env>Env</env>)) ...</envStack>
    [structural]

  syntax K ::= "storeObj"

  rule <k> storeObj => . ...</k>
       <crntObj> Obj (<location> L:Int </location> => .) </crntObj>
       <store>... . => L |-> objectClosure(Obj) ...</store>


/*@ \subsubsection{Self reference}

Like in untyped KOOL. */

  rule <k> this => objectClosure(Obj) ...</k>
       <crntObj> Obj </crntObj>


/*@ \subsubsection{Object member access}

Like in untyped KOOL. */

  rule <k> X:Id => this . X ...</k> <env> Env:Map </env>
    when notBool(X in keys(Env))  [structural]

  context HOLE . _ when (HOLE =/=K super)

  rule objectClosure(<crntClass> Class:Id </crntClass>
                     <envStack>... ListItem((Class,EnvC:Bag)) EStack </envStack>)
       . X:Id
    => lookupMember(<envStack> ListItem((Class,EnvC)) EStack </envStack>, X)
    [structural]

  rule <k> super . X => lookupMember(<envStack>EStack</envStack>, X) ...</k>
       <crntClass> Class </crntClass>
       <envStack>... ListItem((Class,EnvC:Bag)) EStack </envStack>
    [structural]


/*@\subsubsection{Method invocation}

The method lookup is the same as in untyped KOOL.  */

  rule <k> (X:Id => V)(_:Exps) ...</k>
       <env>... X |-> L ...</env>
       <store>... L |-> V:Val ...</store>  [lookup]

  rule <k> (X:Id => this . X)(_:Exps) ...</k>
       <env> Env </env>
    when notBool(X in keys(Env))  [structural]

  context HOLE._::Id(_) when HOLE =/=K super

  rule (objectClosure(Obj:Bag <envStack> EStack </envStack>) . X
    => lookupMember(<envStack> EStack </envStack>, X:Id))(_:Exps)  [structural]

  rule <k> (super . X
            => lookupMember(<envStack>EStack</envStack>,X))(_:Exps)...</k>
       <crntClass> Class </crntClass>
       <envStack>... ListItem((Class,_)) EStack </envStack>
    [structural]

  context HOLE(_:Exps)
    when getKLabel HOLE ==KLabel '_`(_`) orBool getKLabel HOLE ==KLabel '_`[_`]

  rule <k> (lookup(L) => V)(_:Exps) ...</k>  <store>... L |-> V:Val ...</store>
    [lookup]


/*@ \subsubsection{Instance of}

Like in untyped KOOL.  */

  rule objectClosure(<envStack> ListItem((C,_)) ...</envStack> _)
       instanceOf C => true

  rule objectClosure(<envStack> ListItem((C::Id,_)) => . ...</envStack> _)
       instanceOf C'  when C =/=K C'  [structural]

  rule objectClosure(<envStack> . </envStack> _) instanceOf _ => false


/*@ \subsubsection{Cast}

Unlike in untyped KOOL, in typed KOOL we actually check that the object
can indeed be cast to the claimed type. */

  rule (C:Id) objectClosure(<crntClass> _ </crntClass> Obj)
    => objectClosure(Obj) instanceOf C ~> true?
       ~> objectClosure(<crntClass> C </crntClass> Obj)


/*@ \subsection{KOOL-specific auxiliary declarations and operations}

/*@ \subsubsection{Objects as lvalues}

Like in untyped KOOL. */

  rule <k> lvalue(X:Id => this . X) ...</k>  <env> Env </env>
    when notBool(X in keys(Env))  [structural]

  context lvalue(HOLE . _)

  rule lvalue(objectClosure(<crntClass> C </crntClass>
                            <envStack>... ListItem((C,EnvC:Bag)) EStack </envStack>)
              . X
              => lookupMember(<envStack> ListItem((C,EnvC)) EStack </envStack>,
                              X))  [structural]


/*@ \subsubsection{Lookup member}

Like in untyped KOOL. */

  syntax K ::= lookupMember(EnvStackCellSort,Id)  [function]

  rule lookupMember(<envStack> ListItem((_, <env>... X |-> L ...</env>))
                    ...</envStack>, X) => lookup(L)

  rule lookupMember(<envStack> ListItem((_, <env> Env </env>)) => .
                    ...</envStack>, X)  when notBool(X in keys(Env))


//@ \subsubsection{\texttt{typeOf} for the additional values}

  rule typeOf(objectClosure(_ <crntClass> C </crntClass>)) => C
  rule typeOf(methodClosure(T:Type,_,_,Ps:Params,_)) => T


/*@ \subsubsection{Subtype checking}

The subclass relation induces a subtyping relation. */

  syntax Exp ::= subtype(Types,Types)

  rule subtype(T:Type, T) => true  [structural]

  rule <k> subtype(C1:Id, C:Id) => subtype(C2, C) ...</k>
       <className> C1 </className>
       <extends> C2:Id </extends>
    when C1 =/=K C  [structural]

  rule subtype(Object,Class) => false
    when Class =/=K Object  [structural]

  rule subtype(Ts1->T2,Ts1'->T2') => subtype(((T2)::Type,Ts1'),((T2')::Type,Ts1))  [structural]

// Note that the following rule would be wrong!
//  rule subtype(T[],T'[]) => subtype(T,T')

  rule subtype((T:Type,Ts),(T':Type,Ts')) => subtype(T,T') && subtype(Ts,Ts')
    when Ts =/=K .Types  [structural]
  rule subtype(.Types,.Types) => true  [structural]


/*@ \subsubsection{Unsafe Casting}

Performs unsafe casting.  One should only use it in combination with
the subtype relation above. */

  syntax Val ::= unsafeCast(Val,Type)  [function]

  rule unsafeCast(objectClosure(<crntClass>_</crntClass> Obj), C:Id)
    => objectClosure(<crntClass> C </crntClass> Obj)

  rule unsafeCast(methodClosure(T',C,OL,Ps,S), T) => methodClosure(T,C,OL,Ps,S)

  rule unsafeCast(V:Val, T:Type) => V  when typeOf(V) ==K T


/*@ \subsubsection{Generic guard}

A generic computational guard: it allows the computation to continue
only if a prefix guard evaluates to true. */

  syntax K ::= "true?"
  rule true ~> true? => .  [structural]

endmodule
