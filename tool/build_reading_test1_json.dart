// 生成 resource/reading_test1.json：dart run tool/build_reading_test1_json.dart
// Schema：passage_name + question_groups（共用 group_instruction / shared_content，小题仅 question_number、question_text、correct_answer、explanation）
import 'dart:convert';
import 'dart:io';

void main() {
  final List<Map<String, Object?>> passages = <Map<String, Object?>>[
    _passageA(),
    _passageB(),
    _passageC(),
  ];
  final String json = const JsonEncoder.withIndent('  ').convert(passages);
  File('resource/reading_test1.json').writeAsStringSync(json);
  stdout.writeln('Wrote resource/reading_test1.json (${json.length} chars)');
}

Map<String, Object?> _group(
  String groupType,
  String groupInstruction,
  Object? sharedContent,
  List<Map<String, Object?>> questions,
) {
  return <String, Object?>{
    'group_type': groupType,
    'group_instruction': groupInstruction,
    'shared_content': sharedContent,
    'questions': questions,
  };
}

Map<String, Object?> _sub(int n, String questionText, String correctAnswer, String explanation) {
  return <String, Object?>{
    'question_number': n,
    'question_text': questionText,
    'correct_answer': correctAnswer,
    'explanation': explanation,
  };
}

/// 单题 MCQ：选项放在 shared_content，小题不含选项行。
Map<String, Object?> _mcqSingle(
  int n,
  String stem,
  List<String> optionLines,
  String answer,
  String explanation,
) {
  return _group(
    'Multiple Choice',
    'Choose the correct letter, A, B, C or D.',
    optionLines.join('\n'),
    <Map<String, Object?>>[_sub(n, stem, answer, explanation)],
  );
}

Map<String, Object?> _passageA() {
  return <String, Object?>{
    'passage_name': 'Test 1, Passage A',
    'question_groups': <Map<String, Object?>>[
      _mcqSingle(
        1,
        'What does the writer say about Andy Murray’s achievement in 2016?',
        <String>[
          'A. It was expected given his previous tournament record.',
          'B. It was remarkable because of the high level of his competitors.',
          'C. It was primarily due to a complete change in his physical training.',
          'D. It was overshadowed by the reputations of Nadal and Federer.',
        ],
        'B',
        'The text states Murray\'s achievement was "made even more remarkable by the fact that he did this during a period considered to be one of the strongest in the sport\'s history, competing against the likes of Rafael Nadal, Roger Federer and Novak Djokovic...".',
      ),
      _mcqSingle(
        2,
        'According to the second paragraph, what was the "subtle" change Murray made in 2012?',
        <String>[
          'A. He began using a racket made entirely of synthetic material.',
          'B. He invited a new coach to help with his playing style.',
          'C. He changed the type of string used for the vertical parts of his racket.',
          'D. He stopped using natural gut strings altogether.',
        ],
        'C',
        'The passage notes that while he kept natural string for the "crosses" (horizontals), in 2012 he "switched to a synthetic string for the mains" (verticals).',
      ),
      _mcqSingle(
        3,
        'What does Colin Triplow imply about the rackets used by elite professionals?',
        <String>[
          'A. They are mass-produced to meet high market demand.',
          'B. They are significantly lighter than those sold to the general public.',
          'C. They are modified specifically to optimize each player\'s performance.',
          'D. They are available for purchase only in specialized shops in Florida.',
        ],
        'C',
        'Triplow states, "Touring professionals have their rackets customised to their specific needs... each racket is individually made to suit the player who uses it".',
      ),
      _mcqSingle(
        4,
        'Why did the International Tennis Federation ban the "spaghetti-strung" racket?',
        <String>[
          'A. It was deemed too expensive for amateur players to afford.',
          'B. It was manufactured by an uncertified German company.',
          'C. It resulted in an unfair amount of topspin during play.',
          'D. It was prone to breaking and caused safety concerns.',
        ],
        'C',
        'The text explains the spaghetti-strung racket "generated so much topspin that it was quickly banned by the International Tennis Federation".',
      ),
      _group(
        'True/False/Not Given',
        'Do the following statements agree with the information given in the Reading Passage?\n'
            'In boxes 5-9 on your answer sheet, write:\n'
            'TRUE if the statement agrees with the information\n'
            'FALSE if the statement contradicts the information\n'
            'NOT GIVEN if there is no information on this',
        null,
        <Map<String, Object?>>[
          _sub(
            5,
            'Mike and Bob Bryan experimented with the aesthetics of their rackets as well as the technical specifications.',
            'TRUE',
            'The Bryan brothers "experimented with different kinds of paint" (aesthetics) in addition to length and string pattern (specifications).',
          ),
          _sub(
            6,
            'Most professional players prefer to keep their string tension constant regardless of the playing conditions.',
            'FALSE',
            'The text says professionals "continually change it [tension] depending on various factors including the court surface, climatic conditions, and game styles".',
          ),
          _sub(
            7,
            'Synthetic strings were developed in the 1990s because they offered better control than natural gut.',
            'NOT GIVEN',
            'While the text mentions synthetic strings were "cheaper and more durable," it does not state they were developed specifically to provide better control than natural gut.',
          ),
          _sub(
            8,
            'Co-polyester strings are currently the most popular choice among professional tennis players.',
            'TRUE',
            'The passage states, "Of the synthetics, co-polyester is by far the most widely used".',
          ),
          _sub(
            9,
            'Pete Sampras used lead weights to increase the durability of his racket frame.',
            'FALSE',
            'The weights were added for "serving power," not for durability.',
          ),
        ],
      ),
      _group(
        'Summary Completion',
        'Complete the summary below.\nChoose NO MORE THAN TWO WORDS from the passage for each answer.',
        'Further Frame and Handle Modifications',
        <Map<String, Object?>>[
          _sub(
            10,
            'Beyond string adjustments, players often modify the racket frame and handle. For instance, some players choose to have the [BLANK] of a specific racket attached to a different frame to suit their grip preference.',
            'handle',
            'The text mentions players "will have the handle of one racket moulded onto the frame of a different racket".',
          ),
          _sub(
            11,
            'Others, like Goncalo Oliveira, opted for [BLANK] grips because his original ones were not comfortable.',
            'thinner',
            'Oliveira "replaced the original grips... with something thinner because they had previously felt uncomfortable".',
          ),
          _sub(
            12,
            'These modern customizations have allowed the sport to reach [BLANK] that were previously thought impossible.',
            'greater levels',
            'The conclusion states customization has "pushed the standards of the game to greater levels".',
          ),
          _sub(
            13,
            'While players in the past relied on heavy [BLANK] frames, today\'s technology continues to push the boundaries of tennis performance.',
            'wooden',
            'The text contrasts modern rackets with the "days of natural strings and heavy, wooden frames".',
          ),
        ],
      ),
    ],
  };
}

Map<String, Object?> _passageB() {
  return <String, Object?>{
    'passage_name': 'Test 1, Passage B',
    'question_groups': <Map<String, Object?>>[
      _group(
        'Matching Information',
        'The reading passage has seven paragraphs, A-G. Which paragraph contains the following information?\n'
            'Write the correct letter, A-G, in boxes 14-18 on your answer sheet.',
        null,
        <Map<String, Object?>>[
          _sub(
            14,
            'A description of how specific coastal features aided pirate activity.',
            'B',
            'Paragraph B explains that "the numerous coves along the coast providing places for them to hide their boats and strike undetected".',
          ),
          _sub(
            15,
            'An instance where government officials themselves committed an act of piracy.',
            'E',
            'Paragraph E describes an event in 355 BCE where Athenian ambassadors "made a detour from their official travel to capture a ship... taking the wealth found onboard for themselves".',
          ),
          _sub(
            16,
            'A mention of the first specific names given to pirate groups in historical records.',
            'D',
            'Paragraph D mentions the "Amarna Letters" which recorded two distinct groups: "the Lukka and the Sherden".',
          ),
          _sub(
            17,
            'The contrast between the modern cultural image of pirates and their ancient reality.',
            'A',
            'Paragraph A contrasts the modern image of Caribbean "swashbucklers" with the ancient Mediterranean pirates who operated thousands of years earlier.',
          ),
          _sub(
            18,
            'An explanation of how Rome turned former pirates into useful citizens.',
            'G',
            'Paragraph G states that as a long-term solution, many pirates "were offered land in fertile areas... Rome got productive farmers that further boosted its economy".',
          ),
        ],
      ),
      _group(
        'Summary Completion',
        'Complete the summary below.\nChoose NO MORE THAN TWO WORDS from the passage for each answer.',
        'Geography and Piracy',
        <Map<String, Object?>>[
          _sub(
            19,
            'Many inhabitants lived in [BLANK] areas where they had to rely on the sea for resources like fish and salt.',
            'rugged and hilly / mountainous',
            'The text states inhabitants of "rugged and hilly, even mountainous" areas relied on marine resources.',
          ),
          _sub(
            20,
            'Many inhabitants lived in rugged and hilly areas where they had to rely on the sea for resources like [BLANK].',
            'fish and salt',
            'These are the specific marine resources mentioned that the inhabitants relied upon.',
          ),
          _sub(
            21,
            'Because these people were skilled sailors with intimate knowledge of the coast, they turned to piracy during times of [BLANK].',
            'hardships',
            'The passage states that "during hardships, these men turned to piracy".',
          ),
          _sub(
            22,
            'Furthermore, ancient trade was restricted to specific [BLANK] near the shore, making merchant ships easy targets for a pirate ambush.',
            'navigable routes',
            'Ancient ships were "restricted to a few well-known navigable routes that followed the coastline".',
          ),
        ],
      ),
      _group(
        'True/False/Not Given',
        'Do the following statements agree with the information given in the Reading Passage?\n'
            'In boxes 23-26 on your answer sheet, write:\n'
            'TRUE if the statement agrees with the information\n'
            'FALSE if the statement contradicts the information\n'
            'NOT GIVEN if there is no information on this',
        null,
        <Map<String, Object?>>[
          _sub(
            23,
            'Ancient governments occasionally hired pirates to assist their navies during military conflicts.',
            'TRUE',
            'Paragraph C mentions governments "employing their skills and numbers against their opponents," acting as a "first wave of attack".',
          ),
          _sub(
            24,
            'The King of Alashiya admitted to Pharaoh Akhenaten that his people were working with the Lukka pirates.',
            'FALSE',
            'The text states the King of Alashiya "rejected Akhenaten\'s claims of a connection with the Lukka".',
          ),
          _sub(
            25,
            'Unlike the Egyptians, the ancient Greeks generally viewed the lifestyle of pirates with respect.',
            'TRUE',
            'The passage notes that writers like Homer and historians like Thucydides "condones," "praises," and "glorified" the pirates.',
          ),
          _sub(
            26,
            'The Roman Republic took immediate military action as soon as pirates began kidnapping high-ranking officials.',
            'FALSE',
            'Even after pirates kidnapped dignitaries like Julius Caesar, the text says "Rome, however, did nothing, further encouraging piracy." Concerted action didn\'t happen until 67 BCE.',
          ),
        ],
      ),
    ],
  };
}

Map<String, Object?> _passageC() {
  const String groupInst =
      'Look at the following statements (Questions 27-32) and the list of researchers below. Match each statement with the correct researcher or group, A-E.\n'
      'Write the correct letter, A-E, in boxes 27-32 on your answer sheet.\n'
      'NB: You may use any letter more than once.';
  const String researcherList =
      'List of Researchers\n'
      'A. Stephan Lewandowsky & Elizabeth Marsh\n'
      'B. René Descartes\n'
      'C. Baruch Spinoza\n'
      'D. Erik Asp & Daniel Gilbert\n'
      'E. Food and Drug Administration (FDA)';
  return <String, Object?>{
    'passage_name': 'Test 1, Passage C',
    'question_groups': <Map<String, Object?>>[
      _group(
        'Matching People with Statements',
        groupInst,
        researcherList,
        <Map<String, Object?>>[
          _sub(
            27,
            'People initially accept all information as true before a secondary mental process evaluates it.',
            'C',
            'Spinoza argued that "people accept all encountered information (or misinformation) by default and then subsequently verify or reject it through a separate cognitive process".',
          ),
          _sub(
            28,
            'Misinformation can cause a group of people to develop false beliefs that have negative social impacts.',
            'A',
            'Lewandowsky and Marsh suggested that "misperceptions... especially when they occur among large groups of people, may have detrimental, downstream consequences for health, social harmony, and the political climate".',
          ),
          _sub(
            29,
            'Humans only accept or reject a piece of information after they have actively weighed its truthfulness.',
            'B',
            'Descartes argued that "a person only accepts or rejects information after considering its truth or falsehood".',
          ),
          _sub(
            30,
            'The brain uses different physical areas for processing new information versus applying doubt to it.',
            'D',
            'The research of Asp and Gilbert found that the pattern of encoding information as true is "consistent with the observation that mental resources for skepticism physically reside in a different part of the brain".',
          ),
          _sub(
            31,
            'Even after being corrected, false information can still continue to influence a person’s perspective.',
            'E',
            'The passage notes that even with the FDA\'s monitoring, "even misinformation that is successfully corrected can continue to affect attitudes".',
          ),
          _sub(
            32,
            'Inaccurate information can lead individuals to behave differently than they would if they knew the facts.',
            'A',
            'The research teams of Lewandowsky and Marsh suggested misinformation can lead people to "think and act differently than they would if they were correctly informed".',
          ),
        ],
      ),
      _group(
        'Sentence Completion',
        'Complete the sentences below.\nChoose NO MORE THAN TWO WORDS from the passage for each answer.',
        null,
        <Map<String, Object?>>[
          _sub(
            33,
            'While lying has always existed to gain a [BLANK], modern technology has increased the speed and scale of its impact.',
            'strategic advantage',
            'The text states that "Deceiving others can offer an apparent opportunity to gain strategic advantage".',
          ),
          _sub(
            34,
            'In the United States, regulatory bodies usually focus on the [BLANK] of misinformation rather than stopping it before it is broadcast.',
            'post hoc detection',
            'The author notes that regulatory agencies in the U.S. "tend to focus on post hoc detection of broadcast information" rather than "preemptive censoring".',
          ),
          _sub(
            35,
            'The [BLANK] is an example of a system where the public can help identify misleading pharmaceutical advertisements.',
            'Bad Ad program',
            'This is the specific name of the FDA mechanism mentioned where "people can report advertising in apparent violation of FDA guidelines".',
          ),
          _sub(
            36,
            'For a campaign against misinformation to be effective, it must have sufficient [BLANK] and frequency.',
            'reach',
            'The text states that a campaign "requires resources and planning to accomplish necessary reach and frequency".',
          ),
          _sub(
            37,
            'Because some people are unaware that information can be false, researchers suggest teaching [BLANK] to children in school.',
            'media literacy',
            'The passage suggests the "utility of media literacy efforts as early as elementary school".',
          ),
        ],
      ),
      _mcqSingle(
        38,
        'According to the writer, why is it difficult to stop "fake news"?',
        <String>[
          'A. Journalists are often the ones responsible for spreading it.',
          'B. People fail to see the difference between factual stories and false ones when reading quickly.',
          'C. There is a lack of scientific consensus on what constitutes "truth."',
          'D. Digital platforms are legally protected from being censored.',
        ],
        'B',
        'The writer states that "people do not distinguish between demonstrably false stories and those based in fact when scanning and processing written information".',
      ),
      _mcqSingle(
        39,
        'What does the writer suggest about the future of battling misinformation?',
        <String>[
          'A. A single, powerful technological solution will eventually be found.',
          'B. It is a hopeless task because human fallibility is permanent.',
          'C. It will require a long-term, organized effort and constant monitoring.',
          'D. Only government-led censorship can truly solve the problem.',
        ],
        'C',
        'The writer concludes that the journey will be "long and arduous," requiring "continued theoretical consideration," "monitoring tools," and "coordinated efforts over time".',
      ),
      _mcqSingle(
        40,
        'What is the writer’s main purpose in the final paragraph?',
        <String>[
          'A. To criticize the lack of effort from the scientific community.',
          'B. To warn readers that the problem is getting worse every day.',
          'C. To emphasize that solving the issue requires both theory and social cooperation.',
          'D. To argue that human needs for information are the primary cause of lies.',
        ],
        'C',
        'The final paragraph summarizes that overcoming misinformation requires "coordinated efforts" and a "recognition among fellow members of society" to counter claims not based on scientific consensus.',
      ),
    ],
  };
}
