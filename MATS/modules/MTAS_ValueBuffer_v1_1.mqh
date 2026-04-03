// ============================================================================
//  Datei:       MTAS_ValueBuffer_v1_1.mqh
//  Projekt:     MATS (Multi-Asset Trading System)
//  Version:     1.1
//  Letzte Änderung: 2026-04-03
//  Beschreibung: Zirkuläres Buffer-Objekt für Normalisierungen/Z-Score
// ============================================================================

#ifndef __MTAS_VALUEBUFFER_V1_1_MQH
#define __MTAS_VALUEBUFFER_V1_1_MQH

class MTAS_ValueBuffer {
 private:
    double   data[];
    int      size;
    int      pos;
    bool     filled;
 public:
    MTAS_ValueBuffer(void) { size=100; pos=0; filled=false; ArrayResize(data, 100); }
    MTAS_ValueBuffer(const int N) { size=N; pos=0; filled=false; ArrayResize(data, N); }
    void Reset() { pos=0; filled=false; ArrayInitialize(data, 0.0); }
    void Add(const double value) { data[pos++] = value; if(pos>=size) {pos=0; filled=true;} }
    int Count() const { return filled ? size : pos; }
    // Rückgabe: neueste zuerst (data[0]) bis data[Count()-1]
    void GetValues(double &out[]) const {
        int n = Count();
        ArrayResize(out, n);
        for(int i=0;i<n;i++) out[i]=data[(pos-i-1+size)%size];
    }
};
#endif