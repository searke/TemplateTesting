
(* Wolfram Language Package *)

(* See https://github.com/searke/TemplateTesting for documentation *)

BeginPackage["TemplateTesting`"]

randomChoiceCombos::usage = "randomChoiceCombos[lsts, count] generates count number of random combinations of the lists in lsts";
randomChoiceCombos::Invalid = "Invalid Input For randomChoiceCombos: ``";

expandAllCombinations::usage = "expandAllCombinations[table][testingAssertion] expands assertions with a cross product of the values from table"
expandAllCombinations::NotInTable = "Didn't find `1` in table";

testingAssertion::usage = "Wrapper that holds an assertion to test"

testTestingAssertion::usage = "tests a single assertion";
testTestingAssertion::invalid := "The test `1` is not properly formatted";
testTestingAssertion::logic := "The conditional, `1`, did not evaluate to True or False";
testTestingAssertion::notatestingAssertion = "testTestingAssertion must be given a Testing Assertion";

cleanString::Invalid := "cleanString was given the invalid input: `1`";

tag::usage = "a description of a resource in the example set";

Begin["`Private`"] (* Begin Private Context *)

randomChoiceCombos[lst : {Repeated[_List]}, n_Integer?Positive] :=
	Module[{lengths, indices},
		lengths = Map[Length, lst];
		BlockRandom[
			SeedRandom[Method -> {"MKL", Method -> {"Niederreiter", "Dimension" -> Length@lst}}];
			indices = RandomReal[1, {n, Length@lst}] // Map[Times[lengths, # ] &] // Ceiling;
		];
		Map[Inner[Part, lst, #, List] &, indices]
]
randomChoiceCombos[else___] := (Message[randomChoiceCombos::Invalid, ToString@else]; $Failed);

SetAttributes[testingAssertion, HoldAll]
Options[testingAssertion] = {"ID" -> "", "Pre" -> Nothing, "Post" -> Nothing}

associationsToLists = ReplaceAll[Association[content___] :> {content}];

(* tagLookup is similar to Lookup but uses tag expressions.
	tags are a way of handling nested associations and rules.
	The first value for a tag is just a name that is used to make the tag unique when needed.
	tag["a","b"] returns a value with the key tag["a","b"] or just "b".
	tag["a","b","c"] looks for the value with the key key (tag["a","b"])
	and then looks-up "c" in the association it points to.
*)
tagLookup[struct_][tag[{a_, b_, c_}]] :=
	With[{firstOrderLookup = tagLookup[struct][tag[{a, b}]]},
		Lookup[firstOrderLookup,c,
			Missing["tag " <> ToString@b <>" "<>ToString@c <> " not found in table"]]]

tagLookup[struct_][tag[{a_, b_}]] :=
 Lookup[struct, tag[{a, b}],
  Lookup[struct, b,
	Missing["tag " <> ToString@b <> " not found in table"]]]

(* Converts strings in an testingAssertion with underscores into tag expressions.
	"a_example_part1" is converted into tag[{"a", "example", "part1"}] *)
convertStringsToTags[assertion_testingAssertion] :=
	With[{strings = Union@Cases[assertion, _String, Infinity, Heads -> True]},
	With[{stringTags = Union@Select[StringContainsQ["_"]]@strings},
	With[{stingsToTagsRules = AssociationMap[tag[StringSplit[#, "_"]] &, stringTags]},
	ReplaceAll[assertion, stingsToTagsRules]]]]

(* returns all tag expression from a testingAssertion *)
getAllTags[assertion_testingAssertion] :=
	Union@Cases[assertion, _tag, Infinity, Heads -> True]

(* Transforms a list of any tags into a list of basic tags.
	Basic tags are tags of length 2. They don't represent the section of a
	key*)
getBasicTags[tags_] :=
	Union@Map[Replace[tag[{a_, b_, ___}] -> tag[{a, b}]]]@tags

(* Takes a table (list of rules), looks up the tag in the table and replaces
	the tag in assertion with the value from the table*)
applyTagToAssertion[table_][assertion_testingAssertion, tag_tag] :=
	ReplaceAll[assertion, tag -> (tagLookup[table][tag])]

 (* Replaces all tags in the assertion with values found in the table
	which is a list of basic tags *)
applyExpandedTableToAssertion[assertion_][table_] :=
	Fold[applyTagToAssertion[table], assertion, getAllTags@assertion]

expandAllCombinations[table_][assert_testingAssertion] :=
	Module[{tagAssertion, allTags, basictags,expandedbasicTagReplacementRules},
		tagAssertion = convertStringsToTags@assert;
		allTags = getAllTags@tagAssertion;
		basictags = getBasicTags@allTags;
		expandedbasicTagReplacementRules =
			 Map[Thread[basictags -> #] &]@
				Tuples@associationsToLists@Map[tagLookup[table], basictags];
		Map[
			applyExpandedTableToAssertion[tagAssertion],
			expandedbasicTagReplacementRules]
	]

(* Cleans str of anything unacceptable to TestID *)
cleanString[str_String] :=	str//
			Transliterate //
			StringDelete[#, Except[DigitCharacter | LetterCharacter | "-"]] & //
			StringReplace[#, "--" -> "-"] &;
			
 (* theCounter["string"] returns how many times it has seen "string". 
	this is useful for creating sequential counts in testIDs to avoid duplicate testIDs *)
theCounter =
	Module[{hashCounts = <||>, val},
		Function[{hash},
			val = Lookup[hashCounts, Key[hash], hashCounts[hash] = 1];
			hashCounts = MapAt[# + 1 &, hashCounts, hash];
			val
		]
	]

cleanString[otherwise_] := Message[cleanString::Invalid, ToString@otherwise];

(* Converts a list or string into a string suitable for the test system *)
convertToTestIDString[inp__] := cleanString@iconvertToTestIDString[ToString@Hash[{inp}]][inp];
iconvertToTestIDString[hash_]["Counter"] := ToString@theCounter[hash];
iconvertToTestIDString[hash_][str_String] := cleanString[str];
iconvertToTestIDString[hash_][lst_List] :=
	StringRiffle[#,"-"]&@Map[iconvertToTestIDString[hash]]@DeleteCases[#, ""]&@lst;
iconvertToTestIDString[hash_][ent_Entity] :=
	iconvertToTestIDString[hash]@CanonicalName@ent;
iconvertToTestIDString[hash_][else_] :=
	TextString[else];
iconvertToTestIDString[hash_][front_String, rest_String]:=
	iconvertToTestIDString[hash]@front<> "-" <> iconvertToTestIDString[hash]@rest;
iconvertToTestIDString[hash_]["", rest_List]:=
	iconvertToTestIDString[hash][rest]
iconvertToTestIDString[hash_][front_String, ""]:=
	iconvertToTestIDString[hash][front];
iconvertToTestIDString[hash_][front_String, rest_List]:=
	iconvertToTestIDString[hash][front]<> "-" <> iconvertToTestIDString[hash][rest];
iconvertToTestIDString[hash_][else__]:=
	iconvertToTestIDString[hash][{else}];

testTestingAssertion[baseTestID_String:""][testingAssertion[(If|Implies)[cond_, test_], OptionsPattern[]]] :=
	If[cond,
		testTestingAssertion[baseTestID][testingAssertion[test, "ID" :> OptionValue[testingAssertion, "ID"]]],
		Null,
		Message[testTestingAssertion::logic, cond]];

testTestingAssertion[baseTestID_String:""][testingAssertion[SameQ[part1_, part2_], OptionsPattern[]]] :=
	Internal`WithLocalSettings[
		OptionValue[testingAssertion, "Pre"],
		VerificationTest[
			part1,
			part2,
			TestID -> convertToTestIDString[baseTestID, OptionValue[testingAssertion, "ID"]]],
		OptionValue[testingAssertion, "Post"]
	];

comparingFunctions = {Equal, MatchQ, StringMatchQ, SubsetQ, MemberQ, FreeQ, StringFreeQ, StringContainsQ, StringStartsQ, StringEndsQ,
					 IntersectingQ, GeoWithinQ, FreeQ, UnsameQ,
					 ContainsAny, ContainsAll, ContainsNone, ContainsOnly, ContainsExactly,
					 Less, LessEqual, Greater, GreaterEqual};

testTestingAssertion[baseTestID_String:""][testingAssertion[compare_[part1_, part2_] /;(MemberQ[comparingFunctions, compare]), OptionsPattern[]]] :=
	Internal`WithLocalSettings[
		OptionValue[testingAssertion, "Pre"],
		VerificationTest[
				part1,
				part2,
				TestID -> convertToTestIDString[baseTestID, OptionValue[testingAssertion, "ID"]],
				SameTest -> compare],
			OptionValue[testingAssertion, "Post"]];

testTestingAssertion[baseTestID_String:""][testingAssertion[test_, OptionsPattern[]]] :=
	Internal`WithLocalSettings[
		OptionValue[testingAssertion, "Pre"],
		VerificationTest[
			test,
			True,
			TestID -> convertToTestIDString[baseTestID, OptionValue[testingAssertion, "ID"]]],
			OptionValue[testingAssertion, "Post"]];;

testTestingAssertion[___][testingAssertion[___, OptionsPattern[]]] :=
	Message[testTestingAssertion::invalid, OptionValue[testingAssertion, "ID"]];

testTestingAssertion[___][___] :=
	Message[testTestingAssertion::notatestingAssertion];

End[] (* End Private Context *)

EndPackage[]

