/*@ begin PerfTuning (
 def build {
  arg command = 'gcc';
  arg options = '-O3';
 }

 def performance_params {
  param UI[] = [1,2,3,4,5,6,7,8];
 }

 def input_params {
  param N[] = [10000];
 }

 def input_vars {
  decl static double y[N] = 0;
  decl double a1 = random;
  decl double a2 = random;
  decl double a3 = random;
  decl double a4 = random;
  decl static double x1[N] = random;
  decl static double x2[N] = random;
  decl static double x3[N] = random;
  decl static double x4[N] = random;
 }

) @*/

int i;

/*@ begin Loop ( 
    transform Unroll(ufactor=4) 
    for (i=0; i<=N-1; i++)
      y[i] = y[i] + a1*x1[i] + a2*x2[i] + a3*x3[i] + a4*x4[i];
) @*/
for (i=0; i<=N-1; i++)
  y[i] = y[i] + a1*x1[i] + a2*x2[i] + a3*x3[i] + a4*x4[i];
/*@ end @*/
/*@ end @*/
