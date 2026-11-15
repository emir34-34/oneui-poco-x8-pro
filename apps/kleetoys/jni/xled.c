#include <jni.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <android/log.h>
typedef void* (*create_t)(int,int,int,const char*,void*);
typedef void (*an_t)(void*,const void*,unsigned);
typedef unsigned (*res_t)(void*);
typedef void (*vol_t)(void*,float);
static create_t c; static an_t a; static res_t r; static vol_t v; static void* st;
JNIEXPORT jint JNICALL Java_com_klee_toys_Xled_xinit(JNIEnv*e,jclass k,jstring lib,jstring bin,jint sr,jint ch){
  const char* L=(*e)->GetStringUTFChars(e,lib,0); const char* B=(*e)->GetStringUTFChars(e,bin,0);
  void* h=dlopen(L,RTLD_NOW); if(!h){__android_log_print(6,"xled","dlopen %s",dlerror()); return -1;}
  c=(create_t)dlsym(h,"mis_audioled_create"); a=(an_t)dlsym(h,"mis_audioled_analyze_interleaved");
  r=(res_t)dlsym(h,"mis_audioled_get_result"); v=(vol_t)dlsym(h,"mis_audioled_set_current_input_volume");
  if(!c||!a||!r) return -2;
  st=c(sr,ch,16,B,NULL); if(!st) return -3;
  if(v) v(st,1.0f);
  return 0;
}
JNIEXPORT jint JNICALL Java_com_klee_toys_Xled_xproc(JNIEnv*e,jclass k,jshortArray s,jint n){
  jshort* p=(*e)->GetShortArrayElements(e,s,0); a(st,p,(unsigned)n*2); (*e)->ReleaseShortArrayElements(e,s,p,JNI_ABORT);
  return (jint)r(st);
}
JNIEXPORT jboolean JNICALL Java_com_klee_toys_Xled_xhas(JNIEnv*e,jclass k,jstring lib){
  const char* L=(*e)->GetStringUTFChars(e,lib,0);
  void* h=dlopen(L,RTLD_NOW); (*e)->ReleaseStringUTFChars(e,lib,L);
  return h!=NULL;
}
