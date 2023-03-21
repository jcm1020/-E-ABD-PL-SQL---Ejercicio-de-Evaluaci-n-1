drop table precio_combustible cascade constraints;
drop table modelos            cascade constraints;
drop table vehiculos 	      cascade constraints;
drop table clientes 	      cascade constraints;
drop table facturas	      cascade constraints;
drop table lineas_factura     cascade constraints;
drop table reservas			 cascade constraints;

drop sequence seq_modelos;
drop sequence seq_num_fact;
drop sequence seq_reservas;

create table clientes(
	NIF	varchar(9) primary key,
	nombre	varchar(20) not null,
	ape1	varchar(20) not null,
	ape2	varchar(20) not null,
	direccion varchar(40) 
);

create table precio_combustible(
	tipo_combustible	varchar(10) primary key,
	precio_por_litro	numeric(4,2) not null
);

create sequence seq_modelos;

create table modelos(
	id_modelo 		integer primary key,
	nombre			varchar(30) not null,
	precio_cada_dia 	numeric(6,2) not null check (precio_cada_dia>=0),
	capacidad_deposito	integer not null check (capacidad_deposito>0),
	tipo_combustible	varchar(10) not null references precio_combustible);


create table vehiculos(
	matricula	varchar(8)  primary key,
	id_modelo	integer  not null references modelos,
	color		varchar(10)
);

create sequence seq_reservas;
create table reservas(
	idReserva	integer primary key,
	cliente  	varchar(9) references clientes,
	matricula	varchar(8) references vehiculos,
	fecha_ini	date not null,
	fecha_fin	date,
	check (fecha_fin >= fecha_ini)
);

create sequence seq_num_fact;
create table facturas(
	nroFactura	integer primary key,
	importe		numeric( 8, 2),
	cliente		varchar(9) not null references clientes
);

create table lineas_factura(
	nroFactura	integer references facturas,
	concepto	char(40),
	importe		numeric( 7, 2),
	primary key ( nroFactura, concepto)
);
	

create or replace procedure alquilar(arg_NIF_cliente varchar,
  arg_matricula varchar, arg_fecha_ini date, arg_fecha_fin date) is
    /* En respuesta a la pregunta 4, elevar el nivel de aislamiento de la sesion a SERIALZABLE
    consegue que ninguna transaccion que intente realizar una reserva lo consiga antes de realizar
    esta sesion tanto el INSERT en tabla reservas como resultados no actualizados de las sentencias SELECT.
    Otra forma se podria conseguir con la sen tencia SET TRANSACTION READ WRITE, y tambien mediante
    un bloque de tabla LOCK TABLE para que no se pueda insertar en las tablas donde se realiza el SELECT anterior a nuestro INSERT.*/
    
    NUM_DIAS_MAYOR_CERO exception;
    PRAGMA EXCEPTION_INIT( NUM_DIAS_MAYOR_CERO, -20003);
    
    VEHICULO_INEXISTENTE exception;    
    PRAGMA EXCEPTION_INIT( VEHICULO_INEXISTENTE, -20002);
    
    VEHICULO_NO_DISPONIBLE exception;    
    PRAGMA EXCEPTION_INIT( VEHICULO_NO_DISPONIBLE, -20004);
    
    CLIENTE_INEXISTENTE exception;    
    PRAGMA EXCEPTION_INIT( CLIENTE_INEXISTENTE, -20001);
    
    
    v_matricula reservas.matricula%TYPE;
    --reserva reservas%ROWTYPE;
    v_NIF_cliente clientes.nif %TYPE;
    
    TYPE type_registro IS record (
        Id_de_Modelo vehiculos.id_modelo%TYPE,
        Numero_de_Matricula vehiculos.matricula%TYPE,
        Color_del_modelo vehiculos.color%TYPE,
        Nombre_del_modelo modelos.nombre%TYPE,
        Precio_diario modelos.precio_cada_dia%TYPE,
        Capacidad_deposito_en_litros modelos.capacidad_deposito%TYPE,
        Tipo_de_combustible modelos.tipo_combustible%TYPE,
        Precio_por_litro precio_combustible.precio_por_litro%TYPE);
    
    v_registro type_registro;
    
    importe NUMBER(8,2);
    dias NUMBER(8,2);
    numerofactura facturas.nrofactura%TYPE;
    concepto VARCHAR(40);
    
begin
    --SET TRANSACTION READ WRITE;
    begin
        /*SELECT con un par de joins para saber el valor del modelo del
        vehículo pasado como argumento, el prcio de alquilarlo diariamente, la capacidad de su
        depósito de combustible, el tipo de combustible que utiliza y el precio por litro del mismo.*/
        SELECT  a.id_modelo as "Id_de_Modelo",
        a.matricula as "Numero_de_Matricula",
        a.color as "Color_del_modelo",
        b.nombre as "Nombre_del_modelo",
        b.precio_cada_dia as "Precio_diario",
        b.capacidad_deposito as "Capacidad_deposito_en_litros",
        b.tipo_combustible as "Tipo_de_combustible",
        b.precio_por_litro as "Precio_por_litro"
        INTO v_registro
        FROM vehiculos A
        JOIN (SELECT 
        c.id_modelo,
        c.nombre,
        c.precio_cada_dia,
        c.capacidad_deposito,
        c.tipo_combustible,
        d.precio_por_litro
        FROM modelos C
        JOIN precio_combustible D 
        ON c.tipo_combustible = d.tipo_combustible) B
        ON a.id_modelo = b.id_modelo
        WHERE a.matricula = arg_matricula; 
    exception
                when NO_DATA_FOUND then                
                    dbms_output.put_line('No se encontraron datos en SELECT de tabla vehiculos. Vehiculo inexistente');
                    raise_application_error(-20002, 'Vehiculo inexistente.');
    end;
    
    /*Del resultado de esta SELECT se deduce si el vehículo existe. Si no
    existiese se devuelve el error -20002 con el mensaje 'Vehiculo inexistente.'.*/
    --SELECT matricula into v_matricula FROM vehiculos WHERE matricula = arg_matricula;
    --IF  v_registro.Numero_de_Matricula=arg_matricula THEN
    IF  sql%rowcount is null THEN
            raise_application_error(-20002, 'Vehiculo inexistente.');
    ELSE
            dbms_output.put_line('Se procede a alquilar el vehiculo de matricula= '||arg_matricula);
            /*dbms_output.put_line('Id_de_Modelo= '||v_registro.Id_de_Modelo);
            dbms_output.put_line('Numero_de_Matricula= '||v_registro.Numero_de_Matricula);
            dbms_output.put_line('Color_del_modelo= '||v_registro.Color_del_modelo);
            dbms_output.put_line('Nombre_del_modelo= '||v_registro.Nombre_del_modelo);
            dbms_output.put_line('Precio_diario= '||v_registro.Precio_diario);
            dbms_output.put_line('Capacidad_deposito_en_litros= '||v_registro.Capacidad_deposito_en_litros);
            dbms_output.put_line('Tipo_de_combustible= '||v_registro.Tipo_de_combustible);
            dbms_output.put_line('Precio_por_litro= '||v_registro.Precio_por_litro);*/
    END IF;
    
    
    /*1.Comprobar si la fecha de inicio pasada como argumento no es posterior a la fecha fin
    pasada como argumento. En caso contrario devolverá el error -20003 con el mensaje 'El
    numero de dias sera mayor que cero.'*/
    IF trunc(arg_fecha_ini)>trunc(arg_fecha_fin) THEN
        raise_application_error(-20003, 'El numero de dias sera mayor que cero.');
    ELSE       
        
        /*4.Insertamos una fila en la tabla de reservas para el cliente, vehículo e intervalo de fechas
        pasado como argumento. En esta operación deberíamos ser capaces de detectar si el cliente
        no existe, en cuyo caso lanzaremos la excepción -20001, con el mensaje 'Cliente inexistente'.*/
        begin
            SELECT NIF into v_NIF_cliente FROM clientes WHERE nif = arg_NIF_cliente;
        exception
                when NO_DATA_FOUND then
                    dbms_output.put_line('No se encontraron datos en SELECT de tabla clientes');
                    raise_application_error(-20001, 'Cliente inexistente.');
        end;
        IF v_NIF_cliente IS null THEN
        --IF sql%rowcount IS null THEN
            raise_application_error(-20001, 'Cliente inexistente.');
        ELSE
            begin
                /*3.Utilizar una SELECT para saber si en el intervalo entre arg_fecha_ini y arg_fecha_fin no existe ya alguna
                reserva solapada en la tabla de reservas.*/
                SELECT matricula INTO v_matricula FROM reservas WHERE matricula=arg_matricula;
                IF sql%rowcount>0 THEN 
                    raise_application_error(-20004, 'El vehiculo no esta disponible.');
                END IF;
            exception
                when NO_DATA_FOUND then
                    INSERT INTO reservas VALUES (seq_reservas.nextval, arg_NIF_cliente,arg_matricula,arg_fecha_ini,arg_fecha_fin);
                    dbms_output.put_line('No se encontraron datos en SELECT de tabla reservas');
                    --raise_application_error(-20004, 'El vehiculo no esta disponible.');
            end;
            
        END IF;
    END IF;  
    
    /*Apartado 5. Se han intentado crear INSERTs sin exito.*/
    --dias:=arg_fecha_fin-arg_fecha_ini;
    --importe:=(arg_fecha_fin-arg_fecha_ini)*v_registro.Precio_diario;
    --dbms_output.put_line('El importe para la factura sera= '||importe);
    --concepto:='Alquiler de coche por importe '||importe||' euros durante '||dias||' dias';
    --dbms_output.put_line('Alquiler de coche por importe '||importe||'euros durante '||(arg_fecha_fin-arg_fecha_ini)||' dias');
    
    --INSERT INTO facturas VALUES (seq_facturas.nextval, importe, arg_NIF_cliente);
    --INSERT INTO lineas_factura VALUES (seq_lineas_factura.nextval-1, 'Alquiler de vehiculo',importe);
    
end;
/

create or replace
procedure reset_seq( p_seq_name varchar )
--From https://stackoverflow.com/questions/51470/how-do-i-reset-a-sequence-in-oracle
is
    l_val number;
begin
    --Averiguo cual es el siguiente valor y lo guardo en l_val
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    --Utilizo ese valor en negativo para poner la secuencia cero, pimero cambiando el incremento de la secuencia
    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
   --segundo pidiendo el siguiente valor
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    --restauro el incremento de la secuencia a 1
    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/

create or replace procedure inicializa_test is
begin
  reset_seq( 'seq_modelos' );
  reset_seq( 'seq_num_fact' );
  reset_seq( 'seq_reservas' );
        
  
    delete from lineas_factura;
    delete from facturas;
    delete from reservas;
    delete from vehiculos;
    delete from modelos;
    delete from precio_combustible;
    delete from clientes;
   
		
    insert into clientes values ('12345678A', 'Pepe', 'Perez', 'Porras', 'C/Perezoso n1');
    insert into clientes values ('11111111B', 'Beatriz', 'Barbosa', 'Bernardez', 'C/Barriocanal n1');
    
    insert into precio_combustible values ('Gasolina', 1.5);
    insert into precio_combustible values ('Gasoil',   1.4);
    
    insert into modelos values ( seq_modelos.nextval, 'Renault Clio Gasolina', 15, 50, 'Gasolina');
    insert into vehiculos values ( '1234-ABC', seq_modelos.currval, 'VERDE');

    insert into modelos values ( seq_modelos.nextval, 'Renault Clio Gasoil', 16,   50, 'Gasoil');
    insert into vehiculos values ( '1111-ABC', seq_modelos.currval, 'VERDE');
    insert into vehiculos values ( '2222-ABC', seq_modelos.currval, 'GRIS');
	
    commit;
end;
/
exec inicializa_test;


create or replace procedure test_alquila_coches is
begin	 
  --caso 1 nro dias negativo
  begin
    inicializa_test;
    alquilar('12345678A', '1234-ABC', current_date, current_date-1);
    dbms_output.put_line('MAL: Caso nro dias negativo no levanta excepcion');
  exception
    when others then
      if sqlcode=-20003 then
        dbms_output.put_line('OK: Caso nro dias negativo correcto');
      else
        dbms_output.put_line('MAL: Caso nro dias negativo levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end;
  
  --caso 2 vehiculo inexistente
  begin
    inicializa_test;
    alquilar('87654321Z', '9999-ZZZ', date '2013-3-20', date '2013-3-22');
    dbms_output.put_line('MAL: Caso vehiculo inexistente no levanta excepcion');
  exception
    when others then
      if sqlcode=-20002 then
        dbms_output.put_line('OK: Caso vehiculo inexistente correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo inexistente levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end;
  
  --caso 3 cliente inexistente
  begin
    inicializa_test;
    alquilar('87654321Z', '1234-ABC', date '2013-3-20', date '2013-3-22');
    dbms_output.put_line('MAL: Caso cliente inexistente no levanta excepcion');
  exception
    when others then
      if sqlcode=-20001 then
        dbms_output.put_line('OK: Caso cliente inexistente correcto');
      else
        dbms_output.put_line('MAL: Caso cliente inexistente levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end;
  
  --caso 4 Todo correcto pero NO especifico la fecha final 
  declare
                
    resultadoPrevisto varchar(200) := 
      '1234-ABC11/03/1313512345678A4 dias de alquiler, vehiculo modelo 1   60#'||
      '1234-ABC11/03/1313512345678ADeposito lleno de 50 litros de Gasolina 75';
                
    resultadoReal varchar(200)  := '';
    fila varchar(200);
  begin  
    inicializa_test;
    alquilar('12345678A', '1234-ABC', date '2013-3-11', null);
    
    SELECT listAgg(matricula||fecha_ini||fecha_fin||facturas.importe||cliente
								||concepto||lineas_factura.importe, '#')
            within group (order by nroFactura, concepto)
    into resultadoReal
    FROM facturas join lineas_factura using(NroFactura)
                  join reservas using(cliente);
								
    dbms_output.put_line('Caso Todo correcto pero NO especifico la fecha final:');
   if resultadoReal=resultadoPrevisto then
      dbms_output.put_line('--OK SI Coinciden la reserva, la factura y las linea de factura');
    else
      dbms_output.put_line('--MAL NO Coinciden la reserva, la factura o las linea de factura');
      dbms_output.put_line('resultadoPrevisto='||resultadoPrevisto);
      dbms_output.put_line('resultadoReal    ='||resultadoReal);
    end if;
    
  exception   
    when others then
       dbms_output.put_line('--MAL: Caso Todo correcto pero NO especifico la fecha final devuelve '||sqlerrm);
  end;
  
  --caso 5 Intentar alquilar un coche ya alquilado
  
  --5.1 la fecha ini del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	--Reservo del 2013-3-10 al 12
	insert into reservas values
	 (seq_reservas.NEXTVAL, '11111111B', '1234-ABC', date '2013-3-11'-1, date '2013-3-11'+1);
    --Fecha ini de la reserva el 11 
	alquilar('12345678A', '1234-ABC', date '2013-3-11', date '2013-3-13');
	
    dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_ini no levanta excepcion');
	
  exception
    when others then
      if sqlcode=-20004 then
        dbms_output.put_line('OK: Caso vehiculo ocupado solape de fecha_ini correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_ini levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end; 
  
   --5.2 la fecha fin del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	--Reservo del 2013-3-10 al 12
	insert into reservas values
	 (seq_reservas.NEXTVAL, '11111111B', '1234-ABC', date '2013-3-11'-1, date '2013-3-11'+1);
    --Fecha fin de la reserva el 11 
	alquilar('12345678A', '1234-ABC', date '2013-3-7', date '2013-3-11');
	
    dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_fin no levanta excepcion');
	
  exception
    when others then
      if sqlcode=-20004 then
        dbms_output.put_line('OK: Caso vehiculo ocupado solape de fecha_fin correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_fin levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end; 
  
  --5.3 la el intervalo del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	--Reservo del 2013-3-9 al 13
	insert into reservas values
	 (seq_reservas.NEXTVAL, '11111111B', '1234-ABC', date '2013-3-11'-2, date '2013-3-11'+2);
    -- reserva del 4 al 19
	alquilar('12345678A', '1234-ABC', date '2013-3-11'-7, date '2013-3-12'+7);
	
    dbms_output.put_line('MAL: Caso vehiculo ocupado intervalo del alquiler esta dentro de una reserva no levanta excepcion');
	
  exception
    when others then
      if sqlcode=-20004 then
        dbms_output.put_line('OK: Caso vehiculo ocupado intervalo del alquiler esta dentro de una reserva correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo ocupado intervalo del alquiler esta dentro de una reserva levanta excepcion '
        ||sqlcode||' '||sqlerrm);
      end if;
  end; 
  
   --caso 6 Todo correcto pero SI especifico la fecha final 
  declare
                                      
    resultadoPrevisto varchar(400) := '12222-ABC11/03/1313/03/1310212345678A2 dias de alquiler, vehiculo modelo 2   32#'||
                                    '12222-ABC11/03/1313/03/1310212345678ADeposito lleno de 50 litros de Gasoil   70';
                                      
    resultadoReal varchar(400)  := '';    
    fila varchar(200);
  begin
    inicializa_test;
    alquilar('12345678A', '2222-ABC', date '2013-3-11', date '2013-3-13');
    
    SELECT listAgg(nroFactura||matricula||fecha_ini||fecha_fin||facturas.importe||cliente
								||concepto||lineas_factura.importe, '#')
            within group (order by nroFactura, concepto)
    into resultadoReal
    FROM facturas join lineas_factura using(NroFactura)
                  join reservas using(cliente);
    
    
    dbms_output.put_line('Caso Todo correcto pero SI especifico la fecha final');
    
    if resultadoReal=resultadoPrevisto then
      dbms_output.put_line('--OK SI Coinciden la reserva, la factura y las linea de factura');
    else
      dbms_output.put_line('--MAL NO Coinciden la reserva, la factura o las linea de factura');
      dbms_output.put_line('resultadoPrevisto='||resultadoPrevisto);
      dbms_output.put_line('resultadoReal    ='||resultadoReal);
    end if;
    
  exception   
    when others then
       dbms_output.put_line('--MAL: Caso Todo correcto pero SI especifico la fecha final devuelve '||sqlerrm);
  end;
  begin    
    alquilar('12345678A', '1234-ABC', date '2013-3-10', date '2013-3-12');    
  end;
  
end;
/




set serveroutput on
exec test_alquila_coches;
