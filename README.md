TemplateTesting

A package for randomized testing and for testing over exhausting
possible combinations of values.

TemplateTesting supports DRY coding by separating tests into a template
and some data to be repeatedly used on that template.

The package was inspired by Haskell's QuickCheck and Python's Hypothesis
package. Although it differs significantly from it.

TemplateTesting allows you to create templates of tests and fill in
those templates in some non-trivial ways.

testingAssertions
-----------------

"testingAssertions" are symbolic assertions of something that should be
True:
```Mathematica
     myAssertion =  testingAssertion[StringQ["This is a string"], "ID" ->"SimpleTest"] 
```
The "ID" is optional but should always be used. The value will be added
to the TestID of any test ran using it. To actually test this assertion,
it has to be given to the function called "testTestingAssertion".
"testTestingAssertion" first takes a string which is the base of the
TestID and then takes the testing assertion, turning it into a
VerificationTest.
```
     testTestingAssertion["BasicTest"][myAssertion] 
```
This turns into a pretty straightforward VerificationTest, which is
executed immediately.

```     
    VerificationTest[
        StringQ["This is a string"],
        True,
        TestID->"BasicTest-SimpleTest"
    ]
```

"testingAssertion"s provide an extra layer of abstraction which make it
easier to programmatically generating new tests. The TemplateTesting
package provides tools for programmatically generating tests with
"testingAssertion"s.

Generating testingAssertions with expandAllCombinations
-------------------------------------------------------

Supposed we wanted to test that Interpreter\["ComputedDate"\] returned a
DateObject for every day of the week:

```
    myAssertions = {
        testingAssertion[DateObjectQ@Interpreter["ComputedDate"]["Monday"],  "ID" -> "DayOfWeek-Monday"],
        testingAssertion[DateObjectQ@Interpreter["ComputedDate"]["Tuesday"], "ID" -> "DayOfWeek-Tuesday"],
        ....
    }

    Map[testTestingAssertions["SemanticDate"][myAssertions]
```
This is verbose. The templateTesting package provides a function called
**expandAllCombinations** to make this easy:
```
    enumeratedVals = { "DayOfWeek" ->{"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}};

    myAssertionTemplate = testingAssertion[DateObjectQ@Interpreter["ComputedDate"]["a_DayOfWeek"],  "ID" -> "DayOfWeek-"<>"a_DayOfWeek"];

    emyAssertions = ExpandAllCombinations[enumeratedVals][myAssertionTemplate]
```
This generates the list of testingAssertions we wanted. The special part
of this is the string "a\_DayOfWeek". Strings with underscores in them
are special. ExpandAllCombinations takes "a\_DayOfWeek" and replaces all
instances of "a\_DayOfWeek" with a particular value from "DayOfWeek" in
enumeratedVals. The use of "a" before the underscore is not special. We
could have used anythings else. We could have used both "a\_DayOfWeek"
and "b\_DayOfWeek". All instances of "a\_DayofWeek would have been
replaced with the same day of the week, but all instances of
"b\_DayOfWeek" would have been replaced separately.

For example, suppose we want to test that WolframAlpha will always
return a Quantity expression for input like: "Days between Monday and
Tuesday". But we want to run this test for all possible combinations of
days of the week:
```
    enumeratedVals = {"DayOfWeek" -> {"Monday", "Tuesday", "Wednesday",  "Thursday", "Friday", "Saturday", "Sunday"}};

    myAssertionTemplate = 
      testingAssertion[QuantityQ@WolframAlpha[ "Days between " <> "a_DayOfWeek" <> " and " <>  "b_DayOfWeek", {{"Result", 1}, "ComputableData"}]];

    myAssertions = expandAllCombinations[enumeratedVals][myAssertionTemplate]
```
We now have 7 times 7, or 49, testingAssertions! ExpandAllCombinations
produces every possible combination for us.

### An Actual Example of How it is Used in Testing

RandomWord is a function that returns a random value from a WordList.
There are different kinds of WordLists like WordList\["Stopwords"\]. For
every way of calling WordList, there is a corresponding way to call
RandomWord. What if we want to test this? Writing out all the possible
combinations would create an unreadable and difficult to manage test
suite. Here is an example of it could be tested. Let's define some of
the inputs we might use:
```
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
```
    myAssertions = {

       (* For every wordlist type, RandomWord should return an element of that WordlIst *)
        testingAssertion[
            WordList["a_wordListType"] ~ MemberQ ~ RandomWord["a_wordListType"],
            "ID" :> "InWordList-" <> "a_wordListType"
        ], 

        (* RandomWord can be given a number for how many words to return *)
         testingAssertion[
            WordList["a_wordListType"] ~ SubsetQ ~ RandomWord["a_wordListType", "n_rndCountNumber"],
            "ID" :> "CountSubsetQWordList-" <> "a_wordListType"
        ],

         testingAssertion[
            Length@RandomWord["a_wordListType", "n_rndCountNumber"] == "n_rndCountNumber"]
            "ID" :> "RandomWordCount-" <> "a_wordListType"<> "-" <> ToString["n_rndCountNumber"]
        ],

          (* RandomWord can be given a part of speech. This should affect that the result is in the correct WordList *)
          testingAssertion[
             WordList["a_wordListType"] ~ MemberQ ~ RandomWord[{"a_wordListType","b_partOfSpeech"}],
             "ID" :> "SubsetQWordList-PartOfSpeech-" <> "a_wordListType" <> "-" <>"b_partOfSpeech"
        ]
    };
```
We will map expandAllCombinations onto these assertions and then Flatten
them to make a list of testingAssertions.
```
    expandedAssertions = Flatten@Map[expandAllCombinations[enumVals], myAssertions]
```
This generates a lot of tests from just 4 templates. It's easy to keep
track of which "word list types" and which "parts of speech" we have
tests for. Adding tests for new "word list types" will be easy. To test
these, we map "testTestingAssertions" onto the list of expanded
assertions:
```
    Map[testTestingAssertion["RandomWordTesting"], expandedAssertions]
```
Multi-part combinations
-----------------------

I haven't come up with a better name for this yet.

"testAssertions" can be filled in in even more complicated ways.
Consider this simple set of examples for Interpreter\["Number"\]. Each
example has an example input and a corresponding example output stored
as a list of Associations:
```
    enumeratedVals = { "numberExample" ->{

                                   <|"Input" ->"Three"
                                       "Output" -> 3|>,
                                   
                                    <|"Input" ->"2"
                                       "Output" ->2|>,

                                   <|"Input" ->"Seven"
                                       "Output" ->7|>};

    myAssertionTemplate = testingAssertion[
                                              Interpreter["Number"]["a_numberExample"["Input"]]
                                              ==
                                              "a_numberExample"["Output"],  "ID" -> "myID"];

    myAssertions = ExpandAllCombinations[enumeratedVals][myAssertionTemplate]
```
This is a bit clunky. First of all code like:
```
     "a_numberExample"["Input"] 
```
is hard to read. Additionally, when the tests are expanded we don't get
a very readable VerificationTest. The "Input" and "Output" values are
not selected out of the association before it is ran as a test. As a
result we get VerificationTests that look like this:
```
    VerificationTest[
        Interpreter["Number"][<|"Input" ->"Three", "output" -> 3|>["Input"]]
        ,
        <|"Input" ->"Three", "output" -> 3|>["Output"]
        ,
        TestID->"BasicTest-myID"
    ]
```
Fortunately there is a simple syntax for selection components of
associations that is more readable and produces clean looking
VerificationTests. It's just another underscore:
```
    myAssertionTemplate = testingAssertion[
                          	Interpreter["Number"]["a_numberExample_Input"]
                                 ==
                                 "a_numberExample_Output",
                               	 "ID" -> "myID"];
```	
And it produces nicely readable VerificationTests like:
```
    VerificationTest[
        Interpreter["Number"]["Three"]
        ,
       3
        ,
        TestID->"BasicTest-myID"
    ]
```
testAssertion Hijacking
-----------------------

"testingAssertions" will occasionally hijack the code for the test in
"reasonable" ways.

### Logic Hijacking

Certain logic statements, like "If", are special in testingAssertions.
For example,
```
    testingAssertion[If[DayName[Today] == Monday, StringQ["This is a string"]]]
```
This testingAssertion will only run if DayName\[Today\] == Monday.
Otherwise it will not run. In effect it is transformed into:
```
    If[DayName[Today] == Monday, 
       VerificationTest[
        StringQ["This is a string"],
        True,
    ......
        ]
    ]
```
### Operator Hijacking

Some reasonable functions are hijacked and then used as the SameTest of
the VerificationTest. This makes the resulting test easier to read.
```
    testingAssertion[MatchQ[2,_Integer]]
```
This gets transformed into:
```
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

-   Non-roman and accented characters are Transliterated to ASCII. All
    elements of the "ID" that wouldn't be suitable for "TestID" in our
    testing system are converted or removed.
-   "ID" can be given as a list. All the elements of the list will be
    converted to strings and then joined together with dashes. For
    example, you could define "ID" like this:

<!-- -->

    testingAssertion[
        True, 
        "ID" -> {"string", 43, "a_randomNumber", Today}
    ]

Suggestions
-----------

### Insert Random Generators With Defer

Sometimes you want to insert a value without evaluating it. The most
common example is with a random generator or a function that produces a
huge output. Consider this example with RandomImage\[\]. RandomImage\[\]
creates a huge output:
```
        exampleTable = {"ex" :> {RandomImage[]}};

        expandAllCombinations[exampleTable]@
            testingAssertion[ImageQ@"a_ex"]

       ....
```
The resulting testingAssertion contains an actual Image expression in
it. That's huge and unreadable.

The solution is two-fold. First, wrap the RandomImage\[\] in Defer. This
will prevent it's evaluation before being put in the testingAssertion.
Second, give it a concrete randomSeed to use so you can
deterministically reproduce the random image. I usually seed Random
generators in tests with a Hash of Today's date:
```
        exampleTable = {"ex" :> {Defer[RandomSeed[Hash@Today];RandomImage[]]}};

        expandAllCombinations[exampleTable]@testingAssertion[ImageQ@"a_ex"]

        {testingAssertion[ImageQ[RandomSeed[Hash[Today]]; RandomImage[]]]}
```
### Use Infix notation

Infix notation often makes it clear what is being tested and what the
comparison is. For example, I find that Implies is very useful. It works
like "If" does. Suppose that "rndInteger" gives a random Integer:
```
    testingAssertion[EvenQ["a_rndInteger"] ~Implies~ EvenQ[2 + "a_rndInteger"]]
```
This test will only run if "a\_rndInteger" happens to be even. It will
test that adding two to the integer returns an even integer.

### Use Pattern Matching

### Create Default Values For Multi-part Combinations

If you have a list of examples as Associations, very often you will want
default values for some of those fields.

Internally, TemplateTesting runs Lookup on each association to extract
the fields it needs.

Instead of using Associations, you can use your own custom data-type.
Then you can Unprotect Lookup and define Lookup's behavior with that
data-type. Most often, you want Lookup to return a default value for
that datatype when it otherwise doesn't exist.
