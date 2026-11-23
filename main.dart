import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
  tzdata.initializeTimeZones();
  try { tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone())); } catch (_) {}
  await notifications.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()));
  runApp(const SuccessfulLife());
}

class SuccessfulLife extends StatelessWidget {
  const SuccessfulLife({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Successful Life', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF21877C), scaffoldBackgroundColor: const Color(0xFFF8FAF8)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  SharedPreferences? prefs;
  late DateTime start;
  int tab=0;
  Map<String,dynamic> entries={};
  List<bool> reminders=[true,true,true];
  List<int> hours=[8,13,20];
  List<int> minutes=[0,0,0];
  final journal=TextEditingController();
  final priority=TextEditingController();
  int mood=3,energy=3;
  bool completed=false;
  String loadedDay='';
  @override void initState(){super.initState();_load();}
  @override void dispose(){journal.dispose();priority.dispose();super.dispose();}
  Future<void> _load() async {
    prefs=await SharedPreferences.getInstance();
    final p=prefs!;
    start=DateTime.tryParse(p.getString('start')??'')??DateTime.now();
    await p.setString('start',dateKey(start));
    try {entries=Map<String,dynamic>.from(jsonDecode(p.getString('entries')??'{}'));} catch (_) {entries={};}
    reminders=List<bool>.from((jsonDecode(p.getString('reminders')??'[true,true,true]') as List).map((e)=>e==true));
    hours=List<int>.from(jsonDecode(p.getString('hours')??'[8,13,20]'));
    minutes=List<int>.from(jsonDecode(p.getString('minutes')??'[0,0,0]'));
    _refreshDay();
    await _schedule();
    if(mounted)setState((){});
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
    await notifications.cancelAll();
    const labels=['Plan your day','Take your next step','Reflect on today'];
    const details=NotificationDetails(android:AndroidNotificationDetails('daily_routine','Daily reminders',channelDescription:'Your private daily routine',importance:Importance.defaultImportance,priority:Priority.defaultPriority),iOS:DarwinNotificationDetails());
    for(int i=0;i<3;i++){
      if(!reminders[i])continue;
      var time=tz.TZDateTime(tz.local,DateTime.now().year,DateTime.now().month,DateTime.now().day,hours[i],minutes[i]);
      if(!time.isAfter(tz.TZDateTime.now(tz.local)))time=tz.TZDateTime(tz.local,time.year,time.month,time.day+1,hours[i],minutes[i]);
      await notifications.zonedSchedule(i,labels[i],i==1?'A small step counts. Open Successful Life.':'Open your private journal.',time,details,androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,matchDateTimeComponents:DateTimeComponents.time);
    }
    await prefs!.setString('reminders',jsonEncode(reminders));
    await prefs!.setString('hours',jsonEncode(hours));
    await prefs!.setString('minutes',jsonEncode(minutes));
  }
  Future<void> _askPermission() async {
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:true,sound:true);
  }
  Widget panel(Widget child)=>Card(elevation:0,color:Colors.white,child:Padding(padding:const EdgeInsets.all(18),child:child));
  Widget title(String text)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Text(text,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)));
  @override Widget build(BuildContext context){
    if(prefs==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    _refreshDay();
    return Scaffold(
      appBar:AppBar(title:const Text('Successful Life',style:TextStyle(fontWeight:FontWeight.bold))),
      body:SafeArea(child:IndexedStack(index:tab,children:[_today(),_journal(),_progress(),_settings()])),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v){setState(()=>tab=v);},destinations:const [
        NavigationDestination(icon:Icon(Icons.check_circle_outline),label:'Today'),
        NavigationDestination(icon:Icon(Icons.edit_note),label:'Journal'),
        NavigationDestination(icon:Icon(Icons.insights),label:'Progress'),
        NavigationDestination(icon:Icon(Icons.tune),label:'Settings'),
      ]),
    );
  }
  Widget _today()=>ListView(padding:const EdgeInsets.all(18),children:[
    Text('DAY $day OF 90  •  WEEK ${week+1}',style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF21877C))),
    const SizedBox(height:10),LinearProgressIndicator(value:day/90,minHeight:8,borderRadius:BorderRadius.circular(8)),
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
    TextButton.icon(onPressed:()=>setState(()=>tab=1),icon:const Icon(Icons.edit_note),label:const Text('Evening reflection')),
  ]);
  Widget _journal()=>ListView(padding:const EdgeInsets.all(18),children:[
    title('Quick check-in'),
    panel(Column(children:[
      _rating('Mood',mood,(v){setState(()=>mood=v);save();}),
      _rating('Energy',energy,(v){setState(()=>energy=v);save();}),
      const SizedBox(height:12),TextField(controller:journal,maxLines:8,minLines:4,decoration:const InputDecoration(labelText:'What happened? What did I learn?',hintText:'Write as little or as much as you want.',border:OutlineInputBorder()),onChanged:(_)=>save()),
      const SizedBox(height:12),Row(children:[
        Expanded(child:FilledButton.icon(onPressed:()async{await save();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved on this device')));},icon:const Icon(Icons.save_outlined),label:const Text('Save'))),
        const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>Share.share('Successful Life • Day $day\nPriority: ${priority.text}\nMood: $mood/5 • Energy: $energy/5\nJournal:\n${journal.text}\n\nHelp me reflect and suggest one small next action.'),icon:const Icon(Icons.ios_share),label:const Text('Share with AI'))),
      ])
    ])),
    const SizedBox(height:12),title('Past entries'),
    ...entries.keys.toList().reversed.map((key){final e=Map<String,dynamic>.from(entries[key]);return Card(child:ListTile(title:Text(key),subtitle:Text('${e['journal']??''}',maxLines:2,overflow:TextOverflow.ellipsis),onTap:()=>showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(key),content:SingleChildScrollView(child:Text('Priority: ${e['priority']??''}\n\n${e['journal']??''}')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))])));}),
  ]);
  Widget _rating(String label,int value,ValueChanged<int> change)=>Row(children:[Text(label),const Spacer(),...List.generate(5,(i)=>IconButton(visualDensity:VisualDensity.compact,onPressed:()=>change(i+1),icon:Icon(i<value?Icons.circle:Icons.circle_outlined,color:const Color(0xFF21877C),size:20)))]);
  Widget _progress(){final completedDays=entries.values.where((v)=>v is Map && v['completed']==true).length;return ListView(padding:const EdgeInsets.all(18),children:[
    title('Your progress'),panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('$completedDays',style:const TextStyle(fontSize:54,fontWeight:FontWeight.bold)),const Text('days with completed actions'),const SizedBox(height:16),
      Text('Day $day of 90'),const SizedBox(height:8),LinearProgressIndicator(value:day/90,minHeight:10),
      const SizedBox(height:16),const Text('Missing a day never resets your progress.'),
    ])),const SizedBox(height:12),title('Weekly focus'),
    ...List.generate(13,(i)=>ListTile(leading:CircleAvatar(child:Text('${i+1}')),title:Text(themes[i]),subtitle:Text('Days ${i*7+1}–${((i+1)*7).clamp(1,90)}'),trailing:Icon(i<week?Icons.check_circle_outline:i==week?Icons.radio_button_checked:Icons.circle_outlined))),
  ]);}
  Widget _settings()=>ListView(padding:const EdgeInsets.all(18),children:[
    title('Reminders'),const Text('On-device notifications. No account or internet required.'),const SizedBox(height:12),
    ...List.generate(3,(i)=>panel(Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(['Morning plan','Midday action','Evening reflection'][i],style:const TextStyle(fontWeight:FontWeight.bold)),Text(TimeOfDay(hour:hours[i],minute:minutes[i]).format(context))])),
      IconButton(onPressed:()async{final t=await showTimePicker(context:context,initialTime:TimeOfDay(hour:hours[i],minute:minutes[i]));if(t!=null){setState((){hours[i]=t.hour;minutes[i]=t.minute;});await _askPermission();await _schedule();}},icon:const Icon(Icons.schedule)),
      Switch(value:reminders[i],onChanged:(v)async{setState(()=>reminders[i]=v);if(v)await _askPermission();await _schedule();}),
    ]))),
    const SizedBox(height:10),title('Privacy & backup'),
    const Text('Journal entries are saved in app-local storage. Sharing with an AI is always optional and manual. Uninstalling the app may erase its data.'),
    const SizedBox(height:10),OutlinedButton.icon(onPressed:()=>Share.share(const JsonEncoder.withIndent('  ').convert({'start':dateKey(start),'entries':entries})),icon:const Icon(Icons.file_upload_outlined),label:const Text('Export my data')),
    const SizedBox(height:12),const Text('This prototype uses shared_preferences for local storage. For a production release, move journal entries to an encrypted local database and add a verified restore flow.',style:TextStyle(fontSize:12,color:Colors.grey)),
  ]);
}
