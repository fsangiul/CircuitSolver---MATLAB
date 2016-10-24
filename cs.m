%Levanto los datos del circuito
%%nombre= nombre del elemento
%%net1,net2 = nodos a los cuales está conectado (común a todos)
%%net_out = para el caso de operacionales, es el net de salida
%%modelo = que clase de op amp uso (ideal, avol finito, o algún modelo
%%los espacios vacios se los reemplaza por NaN
tic
fileID = fopen('gic.txt');
circuito =textscan(fileID,'%s %f %f %s %s','EmptyValue',NaN);   
  
%%clasifico los datos ingresados según el tipo de elemento

num_elementos=0;
num_resistencias=0;
num_capacitores=0;
num_inductores=0;
num_sources=0;
num_opamps=0;
pasivos=sym();
valores=sym();
op_amp_out=[];

%cuento cuantos elementos hay

[num_elementos,b] = size(circuito{1});

clear b

%Transformo cada string en un símbolo

for i=1:num_elementos,
    simbolos(i,1)= sym(circuito{1}{i},'real');
    
    if strcmp(circuito{1}{i}(1),'O'),
        %circuito{4}(i) = str2num(circuito{4}(i));
        op_amp_out(end+1) = str2double(circuito{4}(i));       
    end
    
end

%cantidad de nodos distintos de tierra

num_nodos = max([op_amp_out,max(circuito{2}),max(circuito{3})]);
B = sym('B');
r_out = sym('r_out');
s = sym('s');

for i=1:num_elementos,
    switch(circuito{1}{i}(1)),
        case 'R',
            num_resistencias=num_resistencias+1;
            R(num_resistencias).nombre=simbolos(i);
            R(num_resistencias).net1=circuito{2}(i);
            R(num_resistencias).net2=circuito{3}(i);
            
            if strcmp(circuito{4}(i),'Symbolic') ~=1 
                R(num_resistencias).valor=str2double(circuito{4}(i));
            else
                R(num_resistencias).valor=nan;
            end
            
        case 'C',
            num_capacitores=num_capacitores+1;
            C(num_capacitores).nombre=simbolos(i);
            C(num_capacitores).net1=circuito{2}(i);
            C(num_capacitores).net2=circuito{3}(i);
            if strcmp(circuito{4}(i),'Symbolic') ~=1 
                C(num_capacitores).valor=str2double(circuito{4}(i));
            else
                C(num_capacitores).valor=nan;
            end
                          
        case 'V',
            num_sources=num_sources+1;
            V(num_sources).nombre=simbolos(i);
            V(num_sources).net1=circuito{2}(i);
            V(num_sources).net2=circuito{3}(i);
            V(num_sources).i_out=sym(strcat('i_v',num2str(num_sources)));
            try
                V(num_sources).Value=circuito{4}(i);
            catch
                V(num_sources).Value=simbolos(i);
            end
        case 'O',
            num_opamps=num_opamps+1;
            Opamp(num_opamps).nombre=simbolos(i);
            Opamp(num_opamps).net_pos=circuito{2}(i);
            Opamp(num_opamps).net_neg=circuito{3}(i);
            Opamp(num_opamps).net_out=str2double(circuito{4}(i));
            Opamp(num_opamps).tipo=circuito{5}(i);
            Opamp(num_opamps).i_out=sym(strcat('i_op',num2str(num_opamps)));
            Opamp(num_opamps).ganancia=B;
            Opamp(num_opamps).r_out=r_out;
    end
   
end

%%Una vez clasificados todos los elementos del circuito, lleno la matriz A
%La matriz A contiene todos los datos del circuito. 

nR=0;
nC=0;
nL=0;
nOp=0;
nV=0;

A=sym(zeros(num_nodos+num_sources+num_opamps));
x=sym(zeros(num_nodos+num_sources+num_opamps,1));
b=sym(zeros(num_nodos+num_sources+num_opamps,1));

for i=1:num_elementos,
    switch(circuito{1}{i}(1)),
        case 'R',
            nR=nR+1;
            pasivos(nR)=R(nR).nombre;
            valores(nR)= R(nR).valor;
            if R(nR).net1==0 || R(nR).net2==0
                
                nodo=max(R(nR).net1,R(nR).net2);
                A(nodo,nodo)= A(nodo,nodo) + (1/R(nR).nombre);
                
            elseif R(nR).net1~=0 && R(nR).net2~=0
                
                A(R(nR).net1,R(nR).net1)= A(R(nR).net1,R(nR).net1) + (1/R(nR).nombre);
                A(R(nR).net2,R(nR).net2)= A(R(nR).net2,R(nR).net2) + (1/R(nR).nombre);
                A(R(nR).net1,R(nR).net2)= A(R(nR).net1,R(nR).net2) - (1/R(nR).nombre);
                A(R(nR).net2,R(nR).net1)= A(R(nR).net2,R(nR).net1) - (1/R(nR).nombre);
                
            end
            
            case 'C',
            nC=nC+1;
            pasivos(num_resistencias+nC)=C(nC).nombre;
            valores(num_resistencias+nC)= C(nC).valor;
            if C(nC).net1==0 || C(nC).net2==0
                
                nodo=max(C(nC).net1,C(nC).net2);
                A(nodo,nodo)= A(nodo,nodo) + (s*C(nC).nombre);
                
            elseif C(nC).net1~=0 && C(nC).net2~=0
                
                A(C(nC).net1,C(nC).net1)= A(C(nC).net1,C(nC).net1) + (s*C(nC).nombre);
                A(C(nC).net2,C(nC).net2)= A(C(nC).net2,C(nC).net2) + (s*C(nC).nombre);
                A(C(nC).net1,C(nC).net2)= A(C(nC).net1,C(nC).net2) - (s*C(nC).nombre);
                A(C(nC).net2,C(nC).net1)= A(C(nC).net2,C(nC).net1) - (s*C(nC).nombre);
                
            end
            
            
            
            case 'L',
            nL=nL+1;
            pasivos(num_resistencias+num_capacitores+nL)=L(nL).nombre;
            valores(num_resistencias+num_capacitores+nL)= L(nL).valor;
            if L(nL).net1==0 || L(nL).net2==0
                
                nodo=max(L(nL).net1,L(nL).net2);
                A(nodo,nodo)= A(nodo,nodo) + (1/L(nL).nombLe);
                
            elseif L(nL).net1~=0 || L(nL).net2~=0
                
                A(L(nL).net1,L(nL).net1)= A(L(nL).net1,L(nL).net1) + (1/(s*L(nL).nombre));
                A(L(nL).net2,L(nL).net2)= A(L(nL).net2,L(nL).net2) + (1/(s*L(nL).nombre));
                A(L(nL).net1,L(nL).net2)= A(L(nL).net1,L(nL).net2) - (1/(s*L(nL).nombre));
                A(L(nL).net2,L(nL).net1)= A(L(nL).net2,L(nL).net1) - (1/(s*L(nL).nombre));
                
            end
            
            case 'V',
            nV=nV+1;
            if V(nV).net1 ~=0
                
                A(num_nodos+nV,V(nV).net1) = 1;
                A(V(nV).net1,num_nodos+nV) = 1; 
                              
            elseif V(nV).net2~=0
                
                A(num_nodos+nV,V(nV).net2) = -1;
                A(V(nV).net2,num_nodos+nV) = -1;
                
            end
            
            case 'O',
            nOp=nOp+1;
            if Opamp(nOp).net_pos ~=0
                
              A(num_nodos+num_sources+nOp,Opamp(nOp).net_pos) = 1;
              
            end
              
            if Opamp(nOp).net_neg ~=0
                
              A(num_nodos+num_sources+nOp,Opamp(nOp).net_neg) = -1;
                
            end
            
            if Opamp(nOp).net_out ~=0
                
                    if strcmp(Opamp(1).tipo,'Ideal') ~=1  
                
                        A(num_nodos+num_sources+nOp,Opamp(nOp).net_out) = B;
                        A(num_nodos+num_sources+nOp,num_nodos+num_sources+nOp) = -Opamp(nOp).r_out*B;
            
                    end   
                
              A(Opamp(nOp).net_out,num_nodos+num_sources+nOp) = 1;      
                    
            end
            
    end
    
end
 
%%Lleno mi vector de incognitas
%Cada nodo tiene una tensión
%Los opamp y fuentes aportan corriente

for i=1:num_nodos,
    x(i)=['v_' num2str(i)];
end

for i=1:num_sources,
    x(i+num_nodos)=V(num_sources).i_out;
end

for i=1:nOp,
    x(i+num_nodos+num_sources)=Opamp(num_opamps).i_out;
end

%%Lleno la matriz b, que contiene las fuentes

for i=1:num_sources,
    b(i+num_nodos)=V(num_sources).nombre;
end

%%El sistema está completamente descripto
%Solo falta resolver el sistema de ecuaciones Ax=b

sol = simplify(linsolve(A,b));

%variables = [symvar(A),symvar(x),symvar(b)];

for i=1:num_elementos,
    syms(circuito{1}{i},'real');
end

for i=1:length(sol),
    eval([char(x(i)) '=' char(sol(i)) ';']);
end

disp(toc)



            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            