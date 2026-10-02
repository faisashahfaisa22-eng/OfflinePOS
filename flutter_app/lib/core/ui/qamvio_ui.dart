import 'package:flutter/material.dart';

class QamvioUi {
  QamvioUi._();

  static const brand=Color(0xFF174EA6);
  static const brandDark=Color(0xFF0F3474);
  static const success=Color(0xFF17795B);
  static const warning=Color(0xFFB56A00);
  static const danger=Color(0xFFB3261E);

  static const pagePadding=EdgeInsets.fromLTRB(16,12,16,96);

  static String money(dynamic value) {
    final n=value is num ? value.toDouble() : double.tryParse('$value')??0;
    return n.toStringAsFixed(2);
  }

  static ThemeData theme() {
    final scheme=ColorScheme.fromSeed(
      seedColor:brand,
      brightness:Brightness.light,
      surface:const Color(0xFFF8FAFD),
    );
    return ThemeData(
      useMaterial3:true,
      colorScheme:scheme,
      scaffoldBackgroundColor:const Color(0xFFF4F7FB),
      appBarTheme:const AppBarTheme(
        centerTitle:false,
        elevation:0,
        scrolledUnderElevation:0,
        backgroundColor:Colors.transparent,
        surfaceTintColor:Colors.transparent,
        titleTextStyle:TextStyle(
          color:Color(0xFF182230),
          fontSize:22,
          fontWeight:FontWeight.w800,
        ),
      ),
      cardTheme:CardThemeData(
        elevation:0,
        margin:EdgeInsets.zero,
        color:Colors.white,
        surfaceTintColor:Colors.transparent,
        shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(20),
          side:const BorderSide(color:Color(0xFFE7ECF3)),
        ),
      ),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,
        fillColor:Colors.white,
        border:OutlineInputBorder(
          borderRadius:BorderRadius.circular(14),
          borderSide:const BorderSide(color:Color(0xFFD9E0E9)),
        ),
        enabledBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(14),
          borderSide:const BorderSide(color:Color(0xFFD9E0E9)),
        ),
        focusedBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(14),
          borderSide:const BorderSide(color:brand,width:1.5),
        ),
        contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
      ),
      filledButtonTheme:FilledButtonThemeData(
        style:FilledButton.styleFrom(
          minimumSize:const Size(0,52),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
          textStyle:const TextStyle(fontWeight:FontWeight.w700),
        ),
      ),
      outlinedButtonTheme:OutlinedButtonThemeData(
        style:OutlinedButton.styleFrom(
          minimumSize:const Size(0,52),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
          side:const BorderSide(color:Color(0xFFD3DBE7)),
          textStyle:const TextStyle(fontWeight:FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme:FloatingActionButtonThemeData(
        backgroundColor:scheme.primary,
        foregroundColor:scheme.onPrimary,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
      ),
      dividerTheme:const DividerThemeData(
        color:Color(0xFFE9EDF3),
        thickness:1,
        space:1,
      ),
      navigationDrawerTheme:const NavigationDrawerThemeData(
        backgroundColor:Colors.white,
        surfaceTintColor:Colors.transparent,
      ),
      bottomSheetTheme:const BottomSheetThemeData(
        backgroundColor:Colors.white,
        surfaceTintColor:Colors.transparent,
        showDragHandle:true,
      ),
      dialogTheme:DialogThemeData(
        backgroundColor:Colors.white,
        surfaceTintColor:Colors.transparent,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
      ),
      snackBarTheme:SnackBarThemeData(
        behavior:SnackBarBehavior.floating,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
      ),
    );
  }
}

class QamvioPageIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const QamvioPageIntro({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(
      gradient:const LinearGradient(
        colors:[Color(0xFF174EA6),Color(0xFF356FD2)],
        begin:Alignment.topLeft,
        end:Alignment.bottomRight,
      ),
      borderRadius:BorderRadius.circular(24),
      boxShadow:const [
        BoxShadow(
          blurRadius:22,
          offset:Offset(0,10),
          color:Color(0x24174EA6),
        ),
      ],
    ),
    child:Row(
      children:[
        Container(
          width:52,
          height:52,
          decoration:BoxDecoration(
            color:Colors.white.withValues(alpha:.14),
            borderRadius:BorderRadius.circular(16),
          ),
          child:Icon(icon,color:Colors.white,size:28),
        ),
        const SizedBox(width:14),
        Expanded(
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text(
                title,
                style:const TextStyle(
                  color:Colors.white,
                  fontSize:22,
                  fontWeight:FontWeight.w800,
                ),
              ),
              const SizedBox(height:4),
              Text(
                subtitle,
                style:TextStyle(
                  color:Colors.white.withValues(alpha:.82),
                  height:1.3,
                ),
              ),
            ],
          ),
        ),
        if(trailing!=null) ...[
          const SizedBox(width:10),
          trailing!,
        ],
      ],
    ),
  );
}

class QamvioSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const QamvioSectionTitle(
    this.title, {
    this.subtitle,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.only(top:8,bottom:10),
    child:Row(
      crossAxisAlignment:CrossAxisAlignment.end,
      children:[
        Expanded(
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text(
                title,
                style:Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight:FontWeight.w800,
                ),
              ),
              if(subtitle!=null) ...[
                const SizedBox(height:3),
                Text(
                  subtitle!,
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:const Color(0xFF667085),
                  ),
                ),
              ],
            ],
          ),
        ),
        if(trailing!=null) trailing!,
      ],
    ),
  );
}

class QamvioStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  const QamvioStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    super.key,
  });

  @override
  Widget build(BuildContext context)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(16),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Container(
            width:40,
            height:40,
            decoration:BoxDecoration(
              color:Theme.of(context).colorScheme.primaryContainer,
              borderRadius:BorderRadius.circular(12),
            ),
            child:Icon(
              icon,
              color:Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines:1,
            overflow:TextOverflow.ellipsis,
            style:Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight:FontWeight.w900,
            ),
          ),
          const SizedBox(height:2),
          Text(
            label,
            maxLines:1,
            overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontWeight:FontWeight.w700),
          ),
          if(caption!=null) ...[
            const SizedBox(height:2),
            Text(
              caption!,
              maxLines:1,
              overflow:TextOverflow.ellipsis,
              style:Theme.of(context).textTheme.bodySmall?.copyWith(
                color:const Color(0xFF667085),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class QamvioEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const QamvioEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context)=>Center(
    child:Padding(
      padding:const EdgeInsets.all(32),
      child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          Container(
            width:76,
            height:76,
            decoration:BoxDecoration(
              color:Theme.of(context).colorScheme.primaryContainer,
              shape:BoxShape.circle,
            ),
            child:Icon(
              icon,
              size:36,
              color:Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height:18),
          Text(
            title,
            textAlign:TextAlign.center,
            style:Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight:FontWeight.w800,
            ),
          ),
          const SizedBox(height:6),
          Text(
            subtitle,
            textAlign:TextAlign.center,
            style:Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:const Color(0xFF667085),
              height:1.35,
            ),
          ),
          if(actionLabel!=null && onAction!=null) ...[
            const SizedBox(height:18),
            FilledButton.icon(
              onPressed:onAction,
              icon:const Icon(Icons.add),
              label:Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

class QamvioActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const QamvioActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context)=>Card(
    child:InkWell(
      borderRadius:BorderRadius.circular(20),
      onTap:onTap,
      child:Padding(
        padding:const EdgeInsets.all(16),
        child:Row(
          children:[
            Container(
              width:46,
              height:46,
              decoration:BoxDecoration(
                color:Theme.of(context).colorScheme.primaryContainer,
                borderRadius:BorderRadius.circular(14),
              ),
              child:Icon(
                icon,
                color:Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width:12),
            Expanded(
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:2),
                  Text(
                    subtitle,
                    maxLines:2,
                    overflow:TextOverflow.ellipsis,
                    style:Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class QamvioAmountPill extends StatelessWidget {
  final String label;
  final dynamic amount;
  final bool strong;

  const QamvioAmountPill({
    required this.label,
    required this.amount,
    this.strong=false,
    super.key,
  });

  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
    decoration:BoxDecoration(
      color:strong
        ?Theme.of(context).colorScheme.primaryContainer
        :const Color(0xFFF1F4F8),
      borderRadius:BorderRadius.circular(999),
    ),
    child:Text(
      '$label ${QamvioUi.money(amount)}',
      style:TextStyle(
        fontSize:12,
        fontWeight:FontWeight.w800,
        color:strong
          ?Theme.of(context).colorScheme.onPrimaryContainer
          :const Color(0xFF344054),
      ),
    ),
  );
}
