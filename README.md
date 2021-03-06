# TemplateTesting

### Randomized testing over exhaustive possible combinations of values.

TemplateTesting is a minimalist templating system that factors otherwise repetitive tests into templates and data. Tests are described as templates which are later filled in with all possible data combinations. 

Many feature of TemplateTesting are inspired by [Haskell's QuickCheck](https://wiki.haskell.org/Introduction_to_QuickCheck1) and [Python's Hypothesis](http://hypothesis.works/). It has many significant differences however, which reflect my personal preferences and features of the Wolfram Language such as homoiconitiy.  

testingAssertions
-----------------

"testingAssertions" are symbolic assertions:

```Mathematica
     myAssertion =
	testingAssertion[
		StringQ["This is a string"],
		"ID" ->"SimpleTest"] 
```

To run a testingAssertion call "testTestingAssertion".
"testTestingAssertion" takes a string which is the base of the
TestID and a testing assertion. It produces a VerificationTest.

```Mathematica
     testTestingAssertion["BasicTest"][myAssertion] 
```

And executes the VerificationtTest.

```Mathematica
    VerificationTest[
        StringQ["This is a string"],
        True,
        TestID->"BasicTest-SimpleTest"
    ]
```

The TemplateTesting package provies tools for running testingAssertions, but also provides tools for programmatically generating and manipulating testingAssertions. This allows it to be useful for statically generating test files or for generating tests at run-time.

Generating testingAssertions with expandAllCombinations
-------------------------------------------------------

Interpreter\["ComputedDate"\] is a function that takes a string and returns which day of the week the a given string might represent. We want to test that Interpreter\["ComputedDate"\] returns a DateObject for every day of the week. One way we might do this is to create a list of testingAssertions - one for each day of the week. In this example, we check that Interpreter returns a valid Date using DateObjectQ:

```Mathematica
    myAssertions = {
        testingAssertion[
		DateObjectQ@Interpreter["ComputedDate"]["Monday"],
		"ID" -> "DayOfWeek-Monday"],
        
	testingAssertion[
		DateObjectQ@Interpreter["ComputedDate"]["Tuesday"],
		"ID" -> "DayOfWeek-Tuesday"],
        ....
    }

    Map[testTestingAssertions["SemanticDate"][myAssertions]
```
This is verbose and repetitive. The templateTesting package provides a function called
**expandAllCombinations** which takes an enumarted list of examples and substitutes them into the assertion. 

```Mathematica
    enumeratedVals = 
	{"DayOfWeek" ->
		{"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}};

    myAssertionTemplate = 
	testingAssertion[
		DateObjectQ@Interpreter["ComputedDate"]["a_DayOfWeek"]
		,
		"ID" -> "DayOfWeek-"<>"a_DayOfWeek"];

    myAssertions =
	 expandAllCombinations[enumeratedVals][myAssertionTemplate]
```
This generates the list of testingAssertions we wanted. The magic part of this is the string "a\_DayOfWeek". This intentionally looks similar to the Wolfram Language's pattern matching syntax. "expandAllCombinations" takes "a\_DayOfWeek" and replaces all instances of "a\_DayOfWeek" with a particular value from "DayOfWeek" in
enumeratedVals. The use of "a" before the underscore is not special. We
could have used anythings else. We could have used both "a\_DayOfWeek"
and "b\_DayOfWeek". All instances of "a\_DayofWeek would have been
replaced with the same day of the week, but all instances of
"b\_DayOfWeek" would have been replaced separately. 

For example, suppose we want to test the WolframAlpha function. It should always return a Quantity expression for input like: "Days between Monday and Tuesday". But we want to run this test for all possible combinations of
days of the week:
```Mathematica
    enumeratedVals =
	 {"DayOfWeek" -> {"Monday", "Tuesday", "Wednesday",  "Thursday", "Friday", "Saturday", "Sunday"}};

    myAssertionTemplate = 
      testingAssertion[
	QuantityQ@WolframAlpha[
		"Days between " <> "a_DayOfWeek" <> " and " <>  "b_DayOfWeek",
		 {{"Result", 1}, "ComputableData"}]];

    myAssertions =
	 expandAllCombinations[enumeratedVals][myAssertionTemplate]
```
Both "a_DayOfWeek" and "b_DayOfWeek" will both be separately replaced with days of the week. This generates 7 times 7, or 49, testingAssertions. expandAllCombinations produces every possible combination for us.

### An Actual Example of How it is Used in Testing

RandomWord is a function that returns a random value from a corresponding WordList. WordList["Stopwords"] for example returns a list of some very common English words and RandomWord["Stopwords"] should return a random word from that list. For
every way of calling WordList, there is a corresponding way to call
RandomWord. What if we want to test this? Writing out all the possible
combinations would create an unreadable and difficult to manage test
suite. Espcially since more kinds of WordLists might be added in the future. Here is an example of it could be tested. Let's define some of
the inputs we might use:
```Mathematica
    enumVals = 
      {
       "wordListType" -> {"CommonWords", "KnownWords", "Stopwords"},
       "partOfSpeech" -> {"Noun", "Verb", "Adjective", "Adverb", "Preposition", "Conjunction", "Pronoun", "Determiner", "Interjection"},
       "rndCountNumber"     :> {RandomInteger[{1,1000}]}
       };
```
Notice that "rndCountNumber" is special. We generate a RandomInteger.
The TemplateTesting package is also very useful in randomly generating
tests. Let's create a list of assertions we would like to check. I've
used Infix notation for much of this. This is a personal preference.
Also note that the "ID" is given a unique value for every possible
combination.
```Mathematica
    myAssertions = {

(* For every wordlist type, RandomWord should return an element of that WordlIst *)
	testingAssertion[
		WordList["a_wordListType"]
		 ~ MemberQ ~ 
		RandomWord["a_wordListType"]
		,
		"ID" :> "InWordList-" <> "a_wordListType"
        ], 

(* RandomWord can be given a number for how many words to return *)
	testingAssertion[
		WordList["a_wordListType"]
		 ~ SubsetQ ~
		 RandomWord["a_wordListType", "n_rndCountNumber"]
		,
		"ID" :> "CountSubsetQWordList-" <> "a_wordListType"
        ],

(* RandomWord should return a list with the specified length  *)
	testingAssertion[
		Length@RandomWord["a_wordListType", "n_rndCountNumber"]
		 ==
		 "n_rndCountNumber"
		,
		"ID" :> "RandomWordCount-" <> "a_wordListType"<> "-" <> ToString["n_rndCountNumber"]
        ],

(* RandomWord can be given a part of speech. This shouldn't affect that the result is in the correct WordList *)
	testingAssertion[
		WordList["a_wordListType"]
		 ~ MemberQ ~ 
		RandomWord[{"a_wordListType","b_partOfSpeech"}]
		,
		"ID" :> "SubsetQWordList-PartOfSpeech-" <> "a_wordListType" <> "-" <>"b_partOfSpeech"
        ]
    };
```
We will map expandAllCombinations onto these assertions and then Flatten
them to make a list of testingAssertions.
```Mathematica
    expandedAssertions = Flatten@Map[expandAllCombinations[enumVals], myAssertions]
```
This generates a lot of tests from just 4 templates. It's easy to keep
track of which "word list types" and which "parts of speech" we have
tests for. Adding tests for new "word list types" will be easy. To test
these, we map "testTestingAssertions" onto the list of expanded
assertions:
```Mathematica
    Map[testTestingAssertion["RandomWordTesting"], expandedAssertions]
```

Note that if we hadn't used any random values, we could just decide to turn the testingAssertions into VerificationTest. TemplateTesting is also useful for creating large, static tests suites.
 
Nested Tags
-----------------------

"testAssertions" can be filled in in even more complicated ways.
So far, we have used strings with one underscore to represent values that should be replaced. These strings are called "tags". The string "a_example" is actually just shorthand for `tag[{"a", "example"}]`. This is considered a simple tag. More complicated tags have 3 instead of 2 parts and allow us to work with more complicated and nested examples.   

The function `Interpreter\["Number"\] takes a string and tries to output the number that it represents. Consider this simple set of examples for Interpreter\["Number"\]. Each example has an example input and a corresponding example output stored as a list of Associations:
```Mathematica
    enumeratedVals =
	{"numberExample" ->{
		<|"Input" ->"Three",
		  "Output" -> 3|>,
                                   
		<|"Input" ->"2",
                  "Output" ->2|>,

		<|"Input" ->"Seven",
		  "Output" ->7|>};

    myAssertionTemplate =
	 testingAssertion[
		Interpreter["Number"]["a_numberExample"["Input"]]
		 ==
		"a_numberExample"["Output"]
		,
		"ID" -> "myID"];

    myAssertions = expandAllCombinations[enumeratedVals][myAssertionTemplate]
```
This is a bit clunky. First of all code like this:
```Mathematica
     "a_numberExample"["Input"] 
```
looks easy to read at first. But remember that when "a_numberExample" is replaced, it will be replaced by the entire Association. We really just want to insert a specific part of the Association, the "Input". This is what we get instead:
```Mathematica
    VerificationTest[
        Interpreter["Number"][<|"Input" ->"Three", "output" -> 3|>["Input"]]
        ,
        <|"Input" ->"Three", "output" -> 3|>["Output"]
        ,
        TestID->"BasicTest-myID"
    ]
```
Fortunately, complex tags allow us to select components of associations. We just add another underscore:
```Mathematica
    myAssertionTemplate = 
	testingAssertion[
		Interpreter["Number"]["a_numberExample_Input"]
		==
		"a_numberExample_Output",
		"ID" -> "myID"];
```	
And it produces nicely readable VerificationTests like:
```Mathematica
    VerificationTest[
        Interpreter["Number"]["Three"]
        ,
      	3
        ,
        TestID->"BasicTest-myID"
    ]
```
The third part of the tag allows us to easily mix in more complicatedexamples. For example, Interpreter\["Number"\] also can take a list of input and automatically maps over that input to produce a list of outputs. We could write a testing assertion to test this 

```Mathematica
	testingAssertion[
		Interpreter["Number"][{"a_numberExample_Input","b_numberExample_Input"}]
		==
		{"a_numberExample_Output", "b_numberExample_Output"},
                "ID" -> "myID"];
```

The resulting VerificationTests are easy to read and exhaustive over every possible combination of "numberExample"s.

testAssertion Hijacking
-----------------------

"testingAssertions" will occasionally hijack the code for the test in
"reasonable" ways.

### Logic Hijacking

Certain logic statements, like "If" and "Imples", are special in testingAssertions.
For example,
```Mathematica
    testingAssertion[If[DayName[Today] == Monday, StringQ["This is a string"]]]
```
This testingAssertion will only run if DayName\[Today\] == Monday.
Otherwise it will not run. In effect it is transformed into:
```Mathematica
    If[DayName[Today] == Monday, 
       VerificationTest[
        StringQ["This is a string"],
        True,
    ......
        ]
    ]
```
The idea is that no reasonable test actually begins with an If statement. We aren't testing the behavior of If. We are instead making a decision about what to test. In practice this is used to restrict certain testingAssertions to only certains kinds of examples. Sometimes we keep a field in a test example that determines if it should be ran with certain testingAssertions. For example, some examples may not work in certain functions. These examples can have fields with a flag in them to prevent them from be ran with those function's testingAssertions.

### Operator Hijacking

Some reasonable functions are hijacked and then used as the SameTest of
the VerificationTest. This makes the resulting test easier to read.
```Mathematica
    testingAssertion[MatchQ[2,_Integer]]
```
This gets transformed into:
```Mathematica
    VerificationTest[
        2, 
        _, 
       SameTest->MatchQ
      ....
    ]
```
If the function is Same, then it is transformed into a regular
VerificationTest.

Special Behavior for "ID"
-------------------------

"ID"s can get complicated when you want to make sure there are unique
IDs for every test. testingAssertions do a number of things to make life
easier.

-   Non-roman and accented characters are transliterated to ASCII. All
    elements of the "ID" that wouldn't be suitable for "TestID" in our
    testing system are converted or removed.
-   "ID" can be given as a list. All the elements of the list will be
    converted to strings and then joined together with dashes. For
    example, you could define "ID" like this:

```Mathematica
    testingAssertion[
        True, 
        "ID" -> {"string", 43, "a_randomNumber", Today}
    ]
```

- The string "Counter" is automatically replaced with an integer that increments whenever that same testID is used. So in the example before, the tests will appear as "MyTest-1", "MyTest-2", and so on.

```Mathematica
    testingAssertion[
        True, 
        "ID" -> {"MyTest", "Counter"}
    ]
```

Suggestions
-----------

### Insert Random Generators With Defer

Sometimes you want to insert a value without evaluating it. The most
common example is with a random generator or a function that produces a
huge output. Consider this example with RandomImage\[\]. RandomImage\[\]
creates a huge output:
```Mathematica

	exampleTable = {"ex" :> {RandomImage[]}};

        expandAllCombinations[exampleTable]@
            testingAssertion[ImageQ@"a_ex"]

       ....
```
The resulting testingAssertion contains an actual Image expression in
it. That's huge and unreadable.

The solution is two-fold. First, wrap the RandomImage\[\] in Defer. This
will prevent its evaluation before being put in the testingAssertion.
Second, give it a concrete randomSeed to use so you can
deterministically reproduce the random image. I usually seed Random
generators in tests with a Hash of Today's date:
```Mathematica
        exampleTable = {"ex" :> {Defer[RandomSeed[Hash@Today];RandomImage[]]}};

        expandAllCombinations[exampleTable]@testingAssertion[ImageQ@"a_ex"]

        {testingAssertion[ImageQ[RandomSeed[Hash[Today]]; RandomImage[]]]}
```
### Use Infix notation

Infix notation often makes it clear what is being tested and what the
comparison is. For example, I find that Implies is very useful. It works
like "If" does. Suppose that "rndInteger" gives a random Integer:
```Mathematica
    testingAssertion[EvenQ["a_rndInteger"] ~Implies~ EvenQ[2 + "a_rndInteger"]]
```
Because of the previously mentioned Operator Hijacking, this test will only run if "a\_rndInteger" happens to be even. It will test that adding two to the integer returns an even integer.

### Use Pattern Matching

This is just something you should do if your language has good pattern matching.Good patterns beat complicated logic statements in terms of readability. 

### Create Default Values For Keys in Your Examples

If you have a list of examples as Associations, very often you will want
default values for some of those fields.

Internally, TemplateTesting runs Lookup on each association to extract
the fields it needs.

Instead of using Associations, you can use your own custom data-type.
Then you can Unprotect Lookup and define Lookup's behavior with that
data-type. Most often, you want Lookup to return a default value for
that datatype when it otherwise doesn't exist.
