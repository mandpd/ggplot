(* :Title: ggplot *)
(* :Context: ggplot` *)
(* :Author: andrewyule *)
(* :Date: 2019-11-10 *)

(* :Package Version: 0.1 *)
(* :Mathematica Version: 11.3 *)
(* :Copyright: (c) 2019 andrewyule *)
(* :Keywords: *)
(* :Discussion: *)

BeginPackage["ggplot`"];
(* Exported symbols added here with SymbolName::usage *)

ggplot::usage     = "TBD";
geomPoint::usage  = "TBD";
geomLine::usage   = "TBD";

Begin["`Private`"];

(*ggPlotGraphics = Graphics;*)
(*SetOptions[ggPlotGraphics, Frame -> True, PlotRange -> All, GridLines -> Automatic, AspectRatio -> 7/10, PlotRangeClipping -> True];*)

(*
  NOTE: Originally I was using Graphics object directly, however, Graphics does not have Options support for ScalingFunction therefore we need to use
  something like ListPlot, but set PlotStyle to be None, then apply the geom's as Epilog functions

  New UPDATE: It may still be better to use Graphics and then we'll write our own ability to do a scaling function.
*)

Options[afsPlot] = Join[Options[ListLinePlot], Options[linearTicks], Options[linearGridLines], {afsPlotFrameQ -> True}, {DateTicksFormat -> Automatic}];
SetOptions[ggplot,
  ImageSize -> 400, AspectRatio -> 7/10, Frame -> True, Axes -> False,
  ImageMargins -> Automatic,
  LabelStyle -> Directive[12, FontFamily -> "Arial"],
  FrameStyle -> Directive[GrayLevel[0.6], Thickness[0.0008`]],
  FrameTicksStyle -> Directive[Black, Opacity[1]],
  FrameTicks -> Automatic, GridLines -> Automatic,  Background -> White,
  PlotRange -> All
];
ggplot[dataset_, geoms : (geomPoint[__] | geomLine[__] | {(geomPoint[__] | geomLine[__])..}), opts : OptionsPattern[]] := Module[{points, lines, scalingFunctionX, scalingFunctionY, graphicsPrimitives, dataForListPlot, graphic},
  points = Cases[geoms, geomPoint[aesthetics__]:> geomPoint[dataset, aesthetics], {0, Infinity}];
  lines = Cases[geoms, geomLine[aesthetics__]:> geomLine[dataset, aesthetics], {0, Infinity}];

  graphicsPrimitives = {Cases[opts, (Epilog -> epi__) :> epi, {0, Infinity}], points, lines} // Flatten;
  (*dataForListPlot = Cases[graphicsForEpilog, {x_?NumericQ, y_?NumericQ}, {0, Infinity}];*)

  scalingFunctionX = With[{f = (OptionValue[ScalingFunctions][[1]] //. {s_?StringQ :> ToExpression[s], None -> Identity})}, Function[f[#]]];
  scalingFunctionY = With[{f = (OptionValue[ScalingFunctions][[2]] //. {s_?StringQ :> ToExpression[s], None -> Identity})}, Function[f[#]]];
  graphicsPrimitives = graphicsPrimitives // ReplaceAll[{x_?NumericQ, y_?NumericQ} :> {scalingFunctionX[x], scalingFunctionY[y]}];

  graphic = Graphics[graphicsPrimitives,
    FrameLabel ->
        If[MatchQ[OptionValue[FrameLabel], {{_?StringQ, _?StringQ}, {_?StringQ, _?StringQ}} | {_?StringQ, _?StringQ} | _?StringQ],
          (OptionValue[FrameLabel] /. str_?StringQ :> Style[str, Opacity[1], FontColor -> Black]),
          OptionValue[FrameLabel]
        ],
    PlotStyle -> OptionValue[PlotStyle],
    ImageSize -> OptionValue[ImageSize],
    AspectRatio -> OptionValue[AspectRatio],
    Frame -> OptionValue[Frame],
    Axes -> OptionValue[Axes],
    LabelStyle -> OptionValue[LabelStyle],
    FrameStyle -> OptionValue[FrameStyle],
    FrameTicksStyle -> OptionValue[FrameTicksStyle],
    FrameTicks -> If[OptionValue[FrameTicks] === Automatic,
      {
        {Function[{minY, maxY}, Alex`Plotting`linearTicks[minY, maxY, FilterRules[Join[{opts}, Options[ggplot]], Options[Alex`Plotting`linearTicks]]]], False},
        {Function[{minX, maxX}, Alex`Plotting`linearTicks[minX, maxX, FilterRules[Join[{opts}, Options[ggplot]], Options[Alex`Plotting`linearTicks]]]], False}
      },
      OptionValue[FrameTicks]
    ],
    GridLines -> If[OptionValue[GridLines] === Automatic,
      {
        Function[{minX, maxX}, Alex`Plotting`linearGridLines[minX, maxX, FilterRules[Join[{opts}, Options[ggplot]], Join[Options[Alex`Plotting`linearTicks], Options[Alex`Plotting`linearGridLines]]]]],
        Function[{minY, maxY}, Alex`Plotting`linearGridLines[minY, maxY, FilterRules[Join[{opts}, Options[ggplot]], Join[Options[Alex`Plotting`linearTicks], Options[Alex`Plotting`linearGridLines]]]]]
      },
      OptionValue[GridLines]
    ],
    GridLinesStyle -> Automatic, (* shouldn't need this but do for some reason *)
    Background -> OptionValue[Background],
    ImageMargins -> OptionValue[ImageMargins],
    FilterRules[{opts} /. (Epilog -> __) :> Nothing, Options[ListPlot]]
  ];

  graphic
];

isDiscreteDataQ[data_] := If[MatchQ[DeleteDuplicates[data], {_?StringQ ..}], True, False];
getDiscreteKeys[data_] := Sort[DeleteDuplicates[data]];
getContinuousRange[data_] := MinMax[data];

(* Functions to determine aesthetics *)

ggplotColorsFunc[1] := Black;
ggplotColorsFunc[numberOfSeries_?IntegerQ] /; numberOfSeries > 1 := Drop[LCHColor[0.65, 0.6, #] & /@ (Subdivide[30, 390, numberOfSeries]/390), -1];
ggplotColorsFunc[___] := ggplotColorsFunc[1];

determineColorFunc[dataset_, key_] := Module[{data, colorFunc, discreteDataQ, keys, minMax},
  data = dataset[[All, key]];
  colorFunc = Function[Black];
  discreteDataQ = isDiscreteDataQ[data];
  If[discreteDataQ,
    keys = getDiscreteKeys[data];
    colorFunc = AssociationThread[keys -> ggplotColorsFunc[Length[keys]]];
  ];
  If[!discreteDataQ,
    minMax = getContinuousRange[data];
    colorFunc = With[{minMax = minMax}, Function[x, Blend[{Red, Blue}, Rescale[x, minMax]]]]
  ];
  colorFunc
];
determineColorFunc[dataset_, Null] := Function[Black];

determineSizeFunc[dataset_, key_] := Module[{data, sizeFunc, discreteDataQ, keys, minMax},
  data = dataset[[All, key]];
  discreteDataQ = isDiscreteDataQ[data];
  (* TODO: We don't really care about discrete data for the size (I think??)*)
  If[discreteDataQ,
    sizeFunc = Function[10];
  ];
  If[!discreteDataQ,
    minMax = getContinuousRange[data];
    sizeFunc = With[{minMax = minMax}, Function[x, Rescale[x, minMax, {5, 20}]]];
  ];
  sizeFunc
];
determineSizeFunc[dataset_, Null] := Function[10];

(* TODO: Implement actual logic for these functions below *)

determineAlphaFunc[] := Function[Opacity[1]];
determineShapeFunc[] := Function["\[FilledCircle]"];
determineThicknessFunc[___] := Function[Thick];
(* determineLineTypeFunc[] := Function[Dashing[1]]; *) (* Need to disable for now as Dashing[1] causes a known Graphics issue with lines flickering. Bug has been reported to Wolfram. *)

(* geomPoint implementation *)

Options[geomPoint] = {"color" -> Null, "size" -> Null, "alpha" -> Null, "shape" -> Null};
geomPoint[dataset_, "x" -> xKey_, "y" -> yKey_, optionalAesthetics : OptionsPattern[]] := Module[{colorFunc, sizeFunc, alphaFunc, shapeFunc, output},
  (* For each key necessary, get functions to be used to specify the aesthetic *)
  colorFunc = determineColorFunc[dataset, OptionValue["color"]];
  sizeFunc = determineSizeFunc[dataset, OptionValue["size"]];
  alphaFunc = determineAlphaFunc[];
  shapeFunc = determineShapeFunc[];

  (*Grab the point data and for each Point apply the correct aesthetic*)
  output = dataset // Map[{
    colorFunc[#[OptionValue["color"]]],
    alphaFunc[#[OptionValue["alpha"]]],
    Inset[Style[shapeFunc[#[OptionValue["shape"]]], sizeFunc[#[OptionValue["size"]]]], {#[xKey], #[yKey]}]
  } &];
  (*
   Group the data by similar aesthetics and then just apply to the first one so we reduce the memory size
   of the output (since graphics will apply the same forms to following expressions)
  *)
  output = output // GroupBy[Most -> Last] // Normal // ReplaceAll[Rule -> List] // Flatten;
  output
];

(* geomLine implementation *)

Options[geomLine] = {"color" -> Null, "thickness" -> Null, "alpha" -> Null, "linetype" -> Null};
geomLine[dataset_, "x" -> xKey_, "y" -> yKey_, optionalAesthetics : OptionsPattern[]] := Module[{groupbyKeys, colorFunc, thicknessFunc, alphaFunc, lineTypeFunc, output},
  (* For each key necessary, get functions to be used to specify the aesthetic *)
  colorFunc = determineColorFunc[dataset, OptionValue["color"]];
  thicknessFunc = determineThicknessFunc[];
  alphaFunc = determineAlphaFunc[];
  (*lineTypeFunc = determineLineTypeFunc[];*)

  (* Group the data and apply correct aesthetics while making a line primitive *)
  groupbyKeys = DeleteCases[{OptionValue["color"], OptionValue["thickness"], OptionValue["alpha"], OptionValue["linetype"]}, Null];
  output = dataset // GroupBy[((# /@ groupbyKeys) &)] // Map[{
    colorFunc[Quiet@#[[1, OptionValue["color"]]]],
    thicknessFunc[Quiet@#[[1, OptionValue["thickness"]]]],
    alphaFunc[Quiet@#[[1, OptionValue["alpha"]]]],
    (*lineTypeFunc[Quiet@#[[1, OptionValue["linetype"]]]],*)
    Line@Sort@Transpose[{#[[All, xKey]], #[[All, yKey]]}]
  } &] // Values;

  output
];

End[]; (* `Private` *)

EndPackage[]