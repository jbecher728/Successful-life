import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'store.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'about.dart';
import 'lock.dart';
import 'tabs.dart';
import 'cloud.dart';
import 'setup.dart';
import 'splash.dart';
import 'planner.dart';
import 'review.dart';
import 'theme.dart';
import 'extras_ui.dart';
import 'rough.dart';
import 'letters.dart';
import 'goal_actions.dart';
import 'today_extras.dart';
import 'onboarding.dart';
import 'exercise.dart';
import 'export.dart';

final notifications = FlutterLocalNotificationsPlugin();
const tasks = <String>[
  'Take stock: rate your six life areas.',
  'List three strengths and three growth areas.',
  'Describe your ideal ordinary day.',
  'Notice three helpful and three unhelpful habits.',
  'Make one good habit easier to do.',
  'Have one meaningful conversation.',
  'Review your week and choose next steps.',
  'Define what success means to you.',
  'Choose three achievable 90-day outcomes.',
  'Break your first outcome into small steps.',
  'Break your second outcome into small steps.',
  'Break your third outcome into small steps.',
  'Plan one action for each outcome.',
  'Review what worked this week.',
];
const themes = <String>[
  'Know yourself', 'Choose your direction', 'Build health',
  'Protect your attention', 'Practice confidence', 'Know your money',
  'Connect deeply', 'Learn and create', 'Build resilience',
  'Think long term', 'Live deliberately', 'Act independently',
  'Reflect and renew',
];
String dateKey(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
DateTime parseDate(String s) => DateTime.parse(s);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
  tzdata.initializeTimeZones();
  try { tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone())); } catch (_) {}
  await notifications.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()));
  }
  notifier = notifications;
  runApp(const SuccessfulLife());
}

class SuccessfulLife extends StatelessWidget {
  const SuccessfulLife({super.key});
  @override Widget build(BuildContext context) => ValueListenableBuilder<(ThemeMode,double)>(valueListenable:look,builder:(context,v,_)=>MaterialApp(
    title: 'Shell', debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: v.$1,
    builder:(c,child)=>MediaQuery(data:MediaQuery.of(c).copyWith(textScaler:TextScaler.linear(v.$2)),child:child!),
    home: const Root(),
  ));
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  Store? prefs;
  late DateTime start;
  int tab=0;
  TabConfig tabs=TabConfig(allTabs.map((t)=>t.id).toList(),<String>{},'today');
  bool inSettings=false;
  Map<String,dynamic> entries={};
  List<bool> reminders=[true,true,true];
  List<int> hours=[8,13,20];
  List<int> minutes=[0,0,0];
  final journal=TextEditingController();
  final priority=TextEditingController();
  int mood=3,energy=3;
  bool completed=false;
  String loadedDay='';
  String? sex;
  String? age;
  List<String> quotes=[];
  List<String> nudges=[];
  @override void initState(){super.initState();_load();}
  @override void dispose(){journal.dispose();priority.dispose();super.dispose();}
  Future<void> _load() async {
    prefs=await Store.getInstance();
    final p=prefs!;
    start=DateTime.tryParse(p.getString('start')??'')??DateTime.now();
    await p.setString('start',dateKey(start));
    if(p.getString('first_run')==null)await p.setString('first_run',dateKey(DateTime.now()));
    try {entries=Map<String,dynamic>.from(jsonDecode(p.getString('entries')??'{}'));} catch (_) {entries={};}
    reminders=List<bool>.from((jsonDecode(p.getString('reminders')??'[true,true,true]') as List).map((e)=>e==true));
    hours=List<int>.from(jsonDecode(p.getString('hours')??'[8,13,20]'));
    minutes=List<int>.from(jsonDecode(p.getString('minutes')??'[0,0,0]'));
    sex=p.getString('sex');
    age=ageGroupFor(p);
    _loadTabs(first:true);
    quotes=await _lines('assets/quotes.txt');
    nudges=await _lines('assets/nudges.txt');
    _refreshDay();
    await _schedule();
    if(mounted)setState((){});
  }
  void _loadTabs({bool first=false}){
    tabs=TabConfig.load(prefs!);
    final v=tabs.visible;
    if(first){tab=v.indexOf(tabs.start);}
    if(tab<0||tab>=v.length)tab=0;
  }
  Widget _pageFor(String id){
    switch(id){
      case 'journal':return _journal();
      case 'connect':return ConnectPage(prefs:prefs!);
      case 'fitness':return FitnessPage(prefs:prefs!,sex:sex,teen:teen,onSex:_setSex);
      default:return _todayHome();
    }
  }
  Future<List<String>> _lines(String path) async {
    try {
      final raw=await rootBundle.loadString(path);
      return raw.split('\n').map((l)=>l.trim()).where((l)=>l.isNotEmpty).toList();
    } catch (_) { return <String>[]; }
  }
  int _dayNum(DateTime d)=>DateTime.utc(d.year,d.month,d.day).difference(DateTime.utc(2024,1,1)).inDays;
  String quoteFor(DateTime d)=>quotes.isEmpty?'Small steps, taken kindly, add up.':quotes[_dayNum(d)%quotes.length];
  bool get teen=>age=='teen';
  String nudgeFor(DateTime d){
    if(nudges.isEmpty)return '';
    final i=_dayNum(d)%nudges.length;
    if(teen){
      for(int k=0;k<3;k++){
        final n=nudges[(i+k)%nudges.length];
        if(!n.startsWith('LOVE|'))return n;
      }
    }
    return nudges[i];
  }

  int get day => DateTime.now().difference(DateTime(start.year,start.month,start.day)).inDays.clamp(0,89)+1;
  int get week => ((day-1)~/7).clamp(0,12);
  String get today => dateKey(DateTime.now());
  String get dailyTask {
    if(day<=14)return tasks[day-1];
    final prompts=['Choose one small action for ${themes[week].toLowerCase()}.','Take that action today.','Remove one obstacle.','Practice the skill for ten minutes.','Notice what improved.','Repeat what worked.','Review and plan the next week.'];
    return prompts[(day-1)%7];
  }
  void _refreshDay(){
    if(prefs==null || loadedDay==today)return;
    loadedDay=today;
    final e=Map<String,dynamic>.from(entries[today]??{});
    journal.text=e['journal']??'';priority.text=e['priority']??'';
    mood=e['mood']??3;energy=e['energy']??3;completed=e['completed']??false;
  }
  Future<void> save(){
    entries[today]={'journal':journal.text,'priority':priority.text,'mood':mood,'energy':energy,'completed':completed,'day':day};
    return prefs!.setString('entries',jsonEncode(entries));
  }
  Future<void> _schedule() async {
    if(kIsWeb)return;
    await notifications.cancelAll();
    const labels=['Plan your day','Take your next step','Reflect on today'];
    const details=NotificationDetails(android:AndroidNotificationDetails('daily_routine','Daily reminders',channelDescription:'Your private daily routine',importance:Importance.defaultImportance,priority:Priority.defaultPriority),iOS:DarwinNotificationDetails());
    final now=tz.TZDateTime.now(tz.local);
    for(int i=0;i<3;i++){
      if(!reminders[i])continue;
      if(i==0){
        // Morning: one notification per day for the next 14 days, each carrying that day's shareable thought.
        for(int d=0;d<14;d++){
          final t=tz.TZDateTime(tz.local,now.year,now.month,now.day+d,hours[0],minutes[0]);
          if(!t.isAfter(now))continue;
          final q=quoteFor(t);
          await notifications.zonedSchedule(100+d,'Good morning',q,t,NotificationDetails(android:AndroidNotificationDetails('daily_quote','Daily thought',channelDescription:'A shareable thought each morning',importance:Importance.defaultImportance,priority:Priority.defaultPriority,styleInformation:BigTextStyleInformation(q)),iOS:const DarwinNotificationDetails()),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime);
        }
        continue;
      }
      var time=tz.TZDateTime(tz.local,now.year,now.month,now.day,hours[i],minutes[i]);
      if(!time.isAfter(now))time=tz.TZDateTime(tz.local,time.year,time.month,time.day+1,hours[i],minutes[i]);
      await notifications.zonedSchedule(i,labels[i],i==1?'A small step counts. Open Shell.':'Open your private journal.',time,details,androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime,matchDateTimeComponents:DateTimeComponents.time);
    }
    final bd=prefs!.getInt('birth_day')??0,bm=prefs!.getInt('birth_month')??0;
    if(bd>0&&bm>0){
      final dd=(bm==2&&bd>28)?28:bd;
      var b=tz.TZDateTime(tz.local,now.year,bm,dd,hours[0],minutes[0]);
      if(!b.isAfter(now))b=tz.TZDateTime(tz.local,now.year+1,bm,dd,hours[0],minutes[0]);
      await notifications.zonedSchedule(200,'Happy birthday! 🎂','Wishing you a great year ahead. A small step today still counts.',b,const NotificationDetails(android:AndroidNotificationDetails('birthday','Birthday greeting',channelDescription:'A yearly birthday greeting',importance:Importance.defaultImportance,priority:Priority.defaultPriority),iOS:DarwinNotificationDetails()),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime,matchDateTimeComponents:DateTimeComponents.dateAndTime);
    }
    await schedulePlanner(notifications,prefs!);
    await scheduleExtras(notifications,prefs!);
    await scheduleLetters(notifications,prefs!);
    await prefs!.setString('reminders',jsonEncode(reminders));
    await prefs!.setString('hours',jsonEncode(hours));
    await prefs!.setString('minutes',jsonEncode(minutes));
  }
  Future<void> _confirmDelete() async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete all data?'),content:const Text('This permanently erases your journal, body log, workouts and settings from this phone. Export first if you want a copy.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete everything'))]));
    if(ok!=true)return;
    await prefs!.disableCloud();
    await prefs!.clear();
    await AppLock.clearPin();
    if(!kIsWeb)await notifications.cancelAll();
    if(!mounted)return;
    await showDialog<void>(context:context,barrierDismissible:false,builder:(ctx)=>const AlertDialog(title:Text('Data deleted'),content:Text('Close the app completely and reopen it to start fresh.')));
  }
  Widget _quoteCard(){
    final q=quoteFor(DateTime.now());
    return panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('TODAY’S THOUGHT',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF21877C))),
      const SizedBox(height:8),Text(q,style:const TextStyle(fontSize:20,fontStyle:FontStyle.italic)),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>Share.share(q),icon:const Icon(Icons.ios_share),label:const Text('Share with someone'))),
    ]));
  }
  Widget _nudgeCard(){
    final raw=nudgeFor(DateTime.now());
    if(raw.isEmpty)return const SizedBox.shrink();
    final parts=raw.split('|');
    final area=parts.length>1?parts[0]:'SELF';
    final text=parts.length>1?parts.sublist(1).join('|'):raw;
    final label={'SELF':'FOR YOURSELF','FRIEND':'FOR A FRIEND','LOVE':'FOR LOVE'}[area]??'TODAY';
    return panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.grey)),
      const SizedBox(height:8),Text(text,style:const TextStyle(fontSize:17)),
    ]));
  }
  Future<void> _askPermission() async {
    if(kIsWeb)return;
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:true,sound:true);
  }
  Widget panel(Widget child)=>Card(elevation:0,color:cardBg(context),child:Padding(padding:const EdgeInsets.all(18),child:child));
  Widget title(String text)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Text(text,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)));
  @override Widget build(BuildContext context){
    if(prefs==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    _refreshDay();
    return Scaffold(
      appBar:AppBar(
        leading:inSettings?IconButton(icon:const Icon(Icons.arrow_back),onPressed:()=>setState(()=>inSettings=false)):null,
        title:Text(inSettings?'Settings':'Shell',style:const TextStyle(fontWeight:FontWeight.bold)),
        actions:inSettings?null:[PopupMenuButton<String>(icon:const Icon(Icons.more_vert),iconSize:20,tooltip:'Menu',onSelected:(v){if(v=='settings'){setState(()=>inSettings=true);}else if(v=='about'){Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const AboutPage()));}else if(v=='privacy'){Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PrivacyPage()));}},itemBuilder:(ctx)=>const [PopupMenuItem<String>(value:'settings',child:Text('Settings')),PopupMenuItem<String>(value:'privacy',child:Text('Privacy notice')),PopupMenuItem<String>(value:'about',child:Text('About'))])],
      ),
      body:SafeArea(child:inSettings?_settings():IndexedStack(index:tab,children:[for(final id in tabs.visible)_pageFor(id)])),
      bottomNavigationBar:tabs.visible.length<2?null:NavigationBar(selectedIndex:tab,onDestinationSelected:(v){setState((){tab=v;inSettings=false;});},destinations:[
        for(final id in tabs.visible)NavigationDestination(icon:Icon(tabDef(id).icon),label:tabDef(id).label),
      ]),
    );
  }
  Widget _todayHome()=>DefaultTabController(length:3,child:Column(children:[
    const TabBar(tabs:[Tab(text:'Today'),Tab(text:'Goals'),Tab(text:'Progress')]),
    Expanded(child:TabBarView(children:[_today(),PlannerPage(prefs:prefs!,onChanged:()async{if(mounted)setState((){});await _askPermission();await schedulePlanner(notifications,prefs!);}),_progress()])),
  ]));
  Future<void> _setSex(String s) async {
    setState(()=>sex=s);
    await prefs!.setString('sex',s);
  }
  Widget _goalsCard(){
    final (d,t)=goalsSummary(prefs!);
    return Builder(builder:(c)=>Card(elevation:0,color:tint(c,const Color(0xFFE8F4F2)),margin:const EdgeInsets.only(top:10),child:ListTile(
      onTap:()=>DefaultTabController.of(c).animateTo(1),
      leading:const Icon(Icons.checklist,color:Color(0xFF21877C)),
      title:Text(t==0?'Add a goal for today':'Goals today: $d of $t done',style:const TextStyle(fontWeight:FontWeight.w700)),
      subtitle:Text(t==0?'Tap to plan something you want to get done.':(d==t?'All done. Well done!':'Tap to see your list and check things off.')),
      trailing:const Icon(Icons.chevron_right),
    )));
  }
  Widget _today()=>ListView(padding:const EdgeInsets.all(18),children:[
    Text('DAY $day OF 90  •  WEEK ${week+1}',style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF21877C))),
    IdentityLine(prefs:prefs!,onChanged:()=>setState((){})),
    _goalsCard(),
    TodayNudges(prefs:prefs!,onChanged:()=>setState((){})),
    const SizedBox(height:10),LinearProgressIndicator(value:day/90,minHeight:8,borderRadius:BorderRadius.circular(8)),
    const SizedBox(height:16),_quoteCard(),const SizedBox(height:12),_nudgeCard(),
    const SizedBox(height:24),title(themes[week]),
    panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('YOUR NEXT STEP',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.grey)),
      const SizedBox(height:12),Text(dailyTask,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w600)),
      const SizedBox(height:22),FilledButton.icon(onPressed:()async{setState(()=>completed=!completed);await save();},icon:Icon(completed?Icons.check_circle:Icons.check),label:Text(completed?'Completed ✓':'Mark complete')),
    ])),
    const SizedBox(height:12),panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('TODAY’S PRIORITY',style:TextStyle(fontWeight:FontWeight.bold)),
      TextField(controller:priority,maxLines:2,decoration:const InputDecoration(hintText:'One thing that matters today...',border:InputBorder.none),onChanged:(_)=>save()),
    ])),
    if(tabs.visible.contains('journal'))TextButton.icon(onPressed:()=>setState(()=>tab=tabs.visible.indexOf('journal')),icon:const Icon(Icons.edit_note),label:const Text('Evening reflection')),
    if(extraOn(prefs!,'rough'))TextButton.icon(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>RoughDayPage(prefs:prefs!,onChanged:()async{await schedulePlanner(notifications,prefs!);if(mounted)setState((){});})));},icon:const Icon(Icons.favorite_border),label:const Text('Having a rough day?')),
  ]);
  Widget _journal()=>ListView(padding:const EdgeInsets.all(18),children:[
    title('Quick check-in'),
    if(extraOn(prefs!,'letters'))Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>LettersPage(prefs:prefs!,onChanged:()async{await scheduleLetters(notifications,prefs!);await _askPermission();})));if(mounted)setState((){});},icon:const Icon(Icons.mail_outline),label:Text(unopenedLetters(prefs!)>0?'Letters to future me (1 arrived!)':'Letters to future me'))),
    if(extraOn(prefs!,'prompt'))Card(elevation:0,color:tint(context,const Color(0xFFFFF8E6)),child:ListTile(
      title:const Text('TODAY’S PROMPT',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold,color:Color(0xFFB7791F))),
      subtitle:Text(journalPromptFor(DateTime.now()),style:const TextStyle(fontSize:16,height:1.3)),
      trailing:TextButton(onPressed:(){if(!journal.text.contains(journalPromptFor(DateTime.now()))){journal.text='${journalPromptFor(DateTime.now())}\n${journal.text}';journal.selection=TextSelection.collapsed(offset:journal.text.length);save();}},child:const Text('Use')),
    )),
    panel(Column(children:[
      _rating('Mood',mood,(v){setState(()=>mood=v);save();}),
      _rating('Energy',energy,(v){setState(()=>energy=v);save();}),
      const SizedBox(height:12),TextField(controller:journal,maxLines:8,minLines:4,decoration:const InputDecoration(labelText:'What happened? What did I learn?',hintText:'Write as little or as much as you want.',border:OutlineInputBorder()),onChanged:(_)=>save()),
      const SizedBox(height:12),Row(children:[
        Expanded(child:FilledButton.icon(onPressed:()async{await save();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved on this device')));},icon:const Icon(Icons.save_outlined),label:const Text('Save'))),
        const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>Share.share('Shell • Day $day\nPriority: ${priority.text}\nMood: $mood/5 • Energy: $energy/5\nJournal:\n${journal.text}\n\nHelp me reflect and suggest one small next action.'),icon:const Icon(Icons.ios_share),label:const Text('Share with AI'))),
      ])
    ])),
    const SizedBox(height:12),title('Past entries'),
    ...entries.keys.toList().reversed.map((key){final e=Map<String,dynamic>.from(entries[key]);return Card(child:ListTile(title:Text(key),subtitle:Text('${e['journal']??''}',maxLines:2,overflow:TextOverflow.ellipsis),onTap:()=>showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(key),content:SingleChildScrollView(child:Text('Priority: ${e['priority']??''}\n\n${e['journal']??''}')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]))));}),
  ]);
  Widget _rating(String label,int value,ValueChanged<int> change)=>Row(children:[Text(label),const Spacer(),...List.generate(5,(i)=>IconButton(visualDensity:VisualDensity.compact,onPressed:()=>change(i+1),icon:Icon(i<value?Icons.circle:Icons.circle_outlined,color:const Color(0xFF21877C),size:20)))]);
  Widget _progress(){final completedDays=entries.values.where((v)=>v is Map && v['completed']==true).length;return ListView(padding:const EdgeInsets.all(18),children:[
    title('Your progress'),
    if(extraOn(prefs!,'egg'))HatchingEgg(prefs:prefs!),
    if(extraOn(prefs!,'mood'))...[const SizedBox(height:10),MoodPatterns(prefs:prefs!)],panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('$completedDays',style:const TextStyle(fontSize:54,fontWeight:FontWeight.bold)),const Text('days with completed actions'),const SizedBox(height:8),Text('${(prefs!.getStringList('ex_log')??<String>[]).length} workouts finished'),const SizedBox(height:16),
      Text('Day $day of 90'),const SizedBox(height:8),LinearProgressIndicator(value:day/90,minHeight:10),
      const SizedBox(height:16),const Text('Missing a day never resets your progress.'),
    ])),const SizedBox(height:12),title('Weekly focus'),
    ...List.generate(13,(i)=>ListTile(leading:CircleAvatar(child:Text('${i+1}')),title:Text(themes[i]),subtitle:Text('Days ${i*7+1}–${((i+1)*7).clamp(1,90)}'),trailing:Icon(i<week?Icons.check_circle_outline:i==week?Icons.radio_button_checked:Icons.circle_outlined))),
  ]);}
  Widget _settings()=>ListView(padding:const EdgeInsets.all(18),children:[
    if(kIsWeb)...[title('Reminders'),const Text('Notifications are not available in the web version. Your daily thought still appears on the Today tab. Install the Android or iPhone app if you want reminders.')] else ...[title('Reminders'),const Text('On-device notifications. No account or internet required.'),const SizedBox(height:12),
    ...List.generate(3,(i)=>panel(Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(['Morning plan','Midday action','Evening reflection'][i],style:const TextStyle(fontWeight:FontWeight.bold)),Text(TimeOfDay(hour:hours[i],minute:minutes[i]).format(context))])),
      IconButton(onPressed:()async{final t=await showTimePicker(context:context,initialTime:TimeOfDay(hour:hours[i],minute:minutes[i]));if(t!=null){setState((){hours[i]=t.hour;minutes[i]=t.minute;});await _askPermission();await _schedule();}},icon:const Icon(Icons.schedule)),
      Switch(value:reminders[i],onChanged:(v)async{setState(()=>reminders[i]=v);if(v)await _askPermission();await _schedule();}),
    ]))),
    const SizedBox(height:6),const Text('Morning reminders show a new shareable thought each day. Open the app every couple of weeks to refresh upcoming ones.',style:TextStyle(fontSize:12,color:Colors.grey)),
    ],
    const SizedBox(height:14),title('Your profile'),
    panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Body type for exercise (required)',style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      SegmentedButton<String>(emptySelectionAllowed:true,segments:const [ButtonSegment<String>(value:'male',label:Text('Male')),ButtonSegment<String>(value:'female',label:Text('Female'))],selected:sex==null?<String>{}:{sex!},onSelectionChanged:(s)async{if(s.isNotEmpty)await _setSex(s.first);}),
      const SizedBox(height:8),
      const Text('Needed to give you the exercises made for your body, and used for body-ratio guidance. Saved on this device only. You can change it any time.',style:TextStyle(fontSize:12,color:Colors.grey)),
    ])),
    const SizedBox(height:14),title('Age group'),
    panel(Text(teen?'Teen mode (ages 13–17), used with a parent or guardian’s approval. It hides weight and BMI tracking, advanced workouts, Deep Core Foundation exercises and romantic prompts. The app switches to Adult mode automatically on your 18th birthday. Your birthday is only stored on this phone.':'Adult mode (18+). Your birthday is only stored on this phone.',style:const TextStyle(fontSize:13,height:1.4))),
    const SizedBox(height:14),title('Look and extras'),
    panel(ExtrasPanel(prefs:prefs!,onChanged:()async{await _schedule();if(mounted)setState((){});})),
    const SizedBox(height:14),title('Opening animation'),
    panel(SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Show opening animation'),subtitle:const Text('A short intro (about 2 seconds) when the app opens.'),value:prefs!.getBool('splash_off')!=true,onChanged:(v)async{await prefs!.setBool('splash_off',!v);setState((){});})),
    const SizedBox(height:14),title('Tabs'),
    panel(TabsEditor(prefs:prefs!,onChanged:()=>setState(()=>_loadTabs()))),
    const SizedBox(height:14),title('Backup'),
    panel(CloudBackupPanel(prefs:prefs!)),
    const SizedBox(height:14),title('App lock'),
    const LockSettingsPanel(),
    const SizedBox(height:14),title('Privacy & your data'),
    const Text('This app never asks for your name, address, city, ZIP code, phone number, email or any account. Nothing is sent anywhere. Your data stays on this phone unless you choose to export it and share the file yourself.'),
    const SizedBox(height:12),
    FilledButton.icon(onPressed:()=>showExportDialog(context,prefs!),icon:const Icon(Icons.archive_outlined),label:const Text('Export my data (zip)')),
    const SizedBox(height:8),
    OutlinedButton.icon(onPressed:()=>importFromZip(context,prefs!),icon:const Icon(Icons.unarchive_outlined),label:const Text('Import from a backup zip')),
    const SizedBox(height:8),
    OutlinedButton.icon(onPressed:_confirmDelete,icon:const Icon(Icons.delete_outline),label:const Text('Delete all my data')),
    const SizedBox(height:12),
    const Text('Storage note: your data is encrypted on this phone, with the key kept in the Android Keystore. Google backup is off unless you turn it on above, and then only a passphrase-locked copy is uploaded. Uninstalling the app deletes its data, so export first if you want to keep it or move to a new phone. Export files are not encrypted.',style:TextStyle(fontSize:12,color:Colors.grey)),
  ]);
}

const connectCats = <String>['Ice Breakers', 'Confessions', 'Getting Deep', 'Challenge'];
const connectFiles = <String>['ice_breakers', 'confessions', 'getting_deep', 'challenge'];
const connectBlurbs = <String>[
  'Easy and playful. Warm up.',
  'Personal, honest and a little revealing.',
  'Slow down. Tender and meaningful.',
  'Small actions to try together or alone.',
];

Future<List<List<String>>> loadConnectDeck() async {
  final deck = <List<String>>[];
  for (final f in connectFiles) {
    final raw = await rootBundle.loadString('assets/questions/$f.txt');
    deck.add(raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList());
  }
  return deck;
}

class ConnectPage extends StatefulWidget {
  final Store prefs;
  const ConnectPage({super.key, required this.prefs});
  @override State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _rng = Random();
  final note = TextEditingController();
  List<List<String>>? deck;
  // Per-category shuffled queues so nothing repeats until a category is used up.
  final List<List<int>> _queues = [<int>[], <int>[], <int>[], <int>[]];
  Set<int> selected = {0, 1, 2, 3};
  bool two = false;
  int player = 0;
  int curCat = 0;
  String question = '';
  int drawn = 0;

  @override void initState() {
    super.initState();
    final saved = widget.prefs.getStringList('connect_cats');
    if (saved != null) {
      final s = saved.map((e) => int.tryParse(e)).whereType<int>().where((i) => i >= 0 && i < 4).toSet();
      if (s.isNotEmpty) selected = s;
    }
    two = widget.prefs.getBool('connect_two') ?? false;
    loadConnectDeck().then((d) {
      if (!mounted) return;
      setState(() { deck = d; _draw(); });
    });
  }
  @override void dispose() { note.dispose(); super.dispose(); }

  void _draw() {
    final d = deck;
    if (d == null) return;
    final cats = selected.toList()..sort();
    final c = cats[_rng.nextInt(cats.length)];
    if (_queues[c].isEmpty) {
      _queues[c] = List<int>.generate(d[c].length, (i) => i)..shuffle(_rng);
    }
    curCat = c;
    question = d[c][_queues[c].removeLast()];
    drawn++;
    note.clear();
  }
  void _next({required bool switchPlayer}) {
    setState(() {
      if (two && switchPlayer) player = 1 - player;
      _draw();
    });
  }
  Future<void> _toggleCat(int i) async {
    final s = Set<int>.from(selected);
    if (s.contains(i)) { if (s.length > 1) s.remove(i); } else { s.add(i); }
    setState(() {
      selected = s;
      if (!selected.contains(curCat)) _draw();
    });
    await widget.prefs.setStringList('connect_cats', (selected.toList()..sort()).map((e) => '$e').toList());
  }
  Future<void> _saveNote() async {
    final text = note.text.trim();
    if (text.isEmpty) return;
    final list = widget.prefs.getStringList('connect_notes') ?? <String>[];
    list.add(jsonEncode({'date': dateKey(DateTime.now()), 'category': connectCats[curCat], 'question': question, 'note': text}));
    await widget.prefs.setStringList('connect_notes', list);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reflection saved on this device')));
  }

  @override Widget build(BuildContext context) {
    if (deck == null) return const Center(child: CircularProgressIndicator());
    final total = deck!.fold<int>(0, (a, b) => a + b.length);
    final mix = selected.length > 1;
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Connect', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('$total questions and challenges. Everything stays on this device.'),
      const SizedBox(height: 14),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(value: false, label: Text('Solo'), icon: Icon(Icons.person_outline)),
          ButtonSegment<bool>(value: true, label: Text('Two people'), icon: Icon(Icons.people_outline)),
        ],
        selected: {two},
        onSelectionChanged: (s) async {
          setState(() { two = s.first; player = 0; note.clear(); });
          await widget.prefs.setBool('connect_two', two);
        },
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Text(mix ? 'Shuffled mix of ${selected.length} categories' : 'Single category: ${connectCats[selected.first]}', style: const TextStyle(fontWeight: FontWeight.w600))),
        TextButton(onPressed: selected.length == 4 ? null : () async {
          setState(() { selected = {0, 1, 2, 3}; });
          await widget.prefs.setStringList('connect_cats', ['0', '1', '2', '3']);
        }, child: const Text('Select all')),
      ]),
      Wrap(spacing: 8, runSpacing: 4, children: List<Widget>.generate(connectCats.length, (i) => FilterChip(
        label: Text('${connectCats[i]} (${deck![i].length})'),
        selected: selected.contains(i),
        onSelected: (_) => _toggleCat(i),
      ))),
      const SizedBox(height: 6),
      const Text('Tap categories to add or remove them. Pick one to stay in it, or several to shuffle between them.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 12),
      Card(elevation: 0, color: cardBg(context), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(connectCats[curCat].toUpperCase() + (two ? '  •  PLAYER ${player + 1} FIRST' : ''), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
        const SizedBox(height: 14),
        Text(question, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(connectBlurbs[curCat], style: const TextStyle(color: Colors.grey)),
        Text(two ? 'Read it aloud, answer, then the other person answers too. Listen without fixing. Skip anything you are not ready for.' : 'Take a moment before you answer. Skip anything you are not ready for.', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _next(switchPlayer: false), child: const Text('Skip'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => _next(switchPlayer: true), child: Text(two ? 'Done, next' : 'Next'))),
        ]),
        TextButton.icon(onPressed: () => Share.share(question), icon: const Icon(Icons.ios_share), label: const Text('Share this question')),
        TextButton.icon(onPressed: () => addToGoalsSheet(context, widget.prefs, 'Talk about: $question'), icon: const Icon(Icons.flag_outlined), label: const Text('Add to my goals')),
      ]))),
      if (!two) ...[
        const SizedBox(height: 12),
        TextField(controller: note, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'Your reflection (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _saveNote, icon: const Icon(Icons.save_outlined), label: const Text('Save reflection')),
      ],
    ]);
  }
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  Store? store;
  String? age;
  bool ready = false;
  bool restore = false;
  bool splashDone = false;
  bool setupDone = false;
  @override void initState() {
    super.initState();
    Store.getInstance().then((s) async {
      if (!mounted) return;
      final fresh = !s.containsKey('birth_year');
      final has = fresh ? await Store.cloudBackupExists() : false;
      if (!mounted) return;
      applyLook(s);
      setState(() { store = s; age = ageGroupFor(s); setupDone = s.getBool('setup_done') == true; restore = has; ready = true; });
    });
  }
  @override Widget build(BuildContext context) {
    if (!ready) return const ColoredBox(color: Color(0xFF21877C));
    final show = !splashDone && store!.getBool('splash_off') != true && !MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: show
          ? SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => splashDone = true))
          : KeyedSubtree(key: const ValueKey('app'), child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (restore) return RestoreScreen(prefs: store!, onDone: () => setState(() { restore = false; age = ageGroupFor(store!); setupDone = store!.getBool('setup_done') == true; }));
    if (age == 'child') return AgeGate(prefs: store!, blocked: true, onDone: (g) => setState(() => age = g));
    if (age == null) return AgeGate(prefs: store!, onDone: (g) => setState(() => age = g));
    if (!setupDone) return SetupPage(prefs: store!, onDone: () => setState(() => setupDone = true));
    return const LockGate(child: HomePage());
  }
}
