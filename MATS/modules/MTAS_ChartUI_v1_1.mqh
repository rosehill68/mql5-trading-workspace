// ============================================================================
//  Datei:       MTAS_ChartUI_v1_1.mqh
//  Beschreibung: ChartButton/UI zum Steuern von Parametern/Ladeaktionen
// ============================================================================

#ifndef __MTAS_CHARTUI_V1_1_MQH
#define __MTAS_CHARTUI_V1_1_MQH

void DrawChartButton(const string btn_name, const string caption, int x, int y, int w = 110, int h = 22)
{
    ObjectDelete(0, btn_name);
    ObjectCreate(0, btn_name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, btn_name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, btn_name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, btn_name, OBJPROP_WIDTH, w);
    ObjectSetInteger(0, btn_name, OBJPROP_HEIGHT, h);
    ObjectSetInteger(0, btn_name, OBJPROP_CORNER, 2); // unten rechts
    ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, clrLightBlue);
    ObjectSetString(0, btn_name, OBJPROP_TEXT, caption);
    ObjectSetInteger(0, btn_name, OBJPROP_FONTSIZE, 10);
}

bool CheckChartButtonClick(const string btn_name, const long event, const string clicked_obj)
{
    return (event == CHARTEVENT_OBJECT_CLICK && clicked_obj == btn_name);
}
#endif