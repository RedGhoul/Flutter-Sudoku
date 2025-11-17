import 'package:flutter/material.dart';

import '../styles.dart';

class AlertNumbersState extends StatefulWidget {
  final bool isPencilMode;
  final Set<int> currentMarks;

  const AlertNumbersState({
    Key? key,
    this.isPencilMode = false,
    this.currentMarks = const {},
  }) : super(key: key);

  @override
  AlertNumbers createState() => AlertNumbers();

  static int? get number {
    return AlertNumbers.number;
  }

  static set number(int? number) {
    AlertNumbers.number = number;
  }

  static Set<int>? get pencilMarks {
    return AlertNumbers.pencilMarks;
  }

  static set pencilMarks(Set<int>? marks) {
    AlertNumbers.pencilMarks = marks;
  }
}

class AlertNumbers extends State<AlertNumbersState> {
  // ignore: avoid_init_to_null
  static int? number = null;
  static Set<int>? pencilMarks;

  late int numberSelected;
  late Set<int> selectedMarks;

  static final List<int> numberList1 = [1, 2, 3];
  static final List<int> numberList2 = [4, 5, 6];
  static final List<int> numberList3 = [7, 8, 9];

  @override
  void initState() {
    super.initState();
    selectedMarks = Set.from(widget.currentMarks);
  }

  List<SizedBox> createButtons(List<int> numberList) {
    return <SizedBox>[
      for (int numbers in numberList)
        SizedBox(
          width: 38,
          height: 38,
          child: TextButton(
            onPressed: () {
              if (widget.isPencilMode) {
                // Toggle mark in pencil mode
                setState(() {
                  if (selectedMarks.contains(numbers)) {
                    selectedMarks.remove(numbers);
                  } else {
                    selectedMarks.add(numbers);
                  }
                });
              } else {
                // Select number in normal mode
                setState(() {
                  numberSelected = numbers;
                  number = numberSelected;
                  Navigator.pop(context);
                });
              }
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(
                widget.isPencilMode && selectedMarks.contains(numbers)
                    ? Styles.primaryColor
                    : Styles.secondaryBackgroundColor,
              ),
              foregroundColor: MaterialStateProperty.all<Color>(
                widget.isPencilMode && selectedMarks.contains(numbers)
                    ? Styles.primaryBackgroundColor
                    : Styles.primaryColor,
              ),
              shape: MaterialStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              )),
              side: MaterialStateProperty.all<BorderSide>(BorderSide(
                color: Styles.foregroundColor,
                width: 1,
                style: BorderStyle.solid,
              )),
            ),
            child: Text(
              numbers.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        )
    ];
  }

  Row oneRow(List<int> numberList) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: createButtons(numberList),
    );
  }

  List<Row> createRows() {
    List<List<int>> numberLists = [numberList1, numberList2, numberList3];
    List<Row> rowList = <Row>[];
    for (var i = 0; i <= 2; i++) {
      rowList.add(oneRow(numberLists[i]));
    }
    return rowList;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Styles.secondaryBackgroundColor,
      title: Center(
          child: Text(
        widget.isPencilMode ? 'Pencil Marks' : 'Choose a Number',
        style: TextStyle(color: Styles.foregroundColor),
      )),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...createRows(),
          if (widget.isPencilMode) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    pencilMarks = null;
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Styles.foregroundColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    pencilMarks = selectedMarks;
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.primaryColor,
                    foregroundColor: Styles.primaryBackgroundColor,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                number = 0;
                Navigator.pop(context);
              },
              child: Text(
                'Clear',
                style: TextStyle(color: Styles.secondaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
