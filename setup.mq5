//+------------------------------------------------------------------+
//|                                                 AutoProfit       |
//|                             Copyright 2021, Julio André C. Faria |
//|                              Setup Baseado no Larry Williams 9.3 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>


#property copyright "2021, Julio A. C. Faria"
#property link "https://github.com/AndreFaria-dev/Setup-9.1"
#property version "1.00"


/*
Julio André
*/

//Guardar os dados (abertura, maxima, minima e fechamento) dos candles dentro de um array para o robô enxergar tendência
//Atualizar arrays cada nova vela

input bool trailling_stop; //Trailling Stop
input double retorno = 2;   //Retorno x risco (Trailling Stop deve estar desabilitado)
input int velas = 1; //Ajustar o stop a cada candlepassada
input int lote = 1; //Numero de ativos (minimo 100 para ações e 1 para contratos futuros)
input int hora_abertura = 09; //Hora de abertura 
input int minuto_abertura = 30; //Minuto de abertura
input int hora_encerramento = 16;//Hora de encerramento
input int minuto_encerramento = 00; //Minuto de encerramento
input int stop_dia = 2; //Stop loss por dia

//Variaveis não parametrizadas

double preco_start_pos;    //Gravar o valor do preço ao executar um trade
int stop_count=0;   //Operações realizadas a cada inicialização do robô
const int periodo = 9;//Período da média movel

//Manipuladores
int mmeHandle = INVALID_HANDLE;

double mmexponencial[];//Array para passar os dados da média móvel

//Struct para captar dados de candles

struct Candle
  {
   double            open[10],high[10],low[10],close[10];     
   bool              touro;     
   double            tamanho_corpo; //Body size
   
  };
//Candle vela; //declaração da variavel
//Obtém os valores Open High Low Close
MqlRates candle[];

CTrade meutrade; //Criando um objeto para realizar ordens



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()//Inicialização do algoritmo
  {

   ArraySetAsSeries(mmexponencial,true);
   ArraySetAsSeries(candle,true);
   int deslocamentoMedia=0;

   //atribuir para a manipulação da média movel
   mmeHandle = iMA(_Symbol,_Period,periodo,deslocamentoMedia,MODE_EMA,PRICE_CLOSE);

   return(INIT_SUCCEEDED);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()//Executa essa função em cada atualização do preço
  {
  
  double ask_compra = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
  double bid_venda = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
  
  double saldo_pos = PositionGetDouble(POSITION_PROFIT);
  

  
   if(isNovaVela()) //Executar ordens apenas quando aparece um novo candle
     {
     
      Print("Abertura",candle[1].open);
      
      //Obtenção dos dados
      
      int candles = 10; //Quantidade de velas para ler uma tendência

      int copied = CopyBuffer(mmeHandle,0,0,candles,mmexponencial);
      int copied_rates = CopyRates(_Symbol,_Period, 0,100,candle);
      
      
      double preco_stop_pos = PositionGetDouble(POSITION_SL);
      ulong PositionTicket= PositionGetInteger(POSITION_TICKET);

      
      //Inicialização
      bool isComprado = false;
      bool isVendido = false;

      
      bool stop_loss = 0;

      //Verificar posição aberta
      if(PositionSelect(_Symbol))
        {
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            isComprado = true;
           }
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            isVendido = true;
           }
        }


      //printf("\nDEPURAÇÃO\nisComprado: %d \nisVendido: %d \nMédia Móvel: %f\npreco_stop_pos: %d\n",isComprado,isVendido,mmexponencial[1],preco_stop_pos);
      
      if(isHorarioNegociacao())
        {
         int touros=0; //Contar velas acima da media movel
         double preco_alvo_pos;
         




         if(!isComprado && !isVendido) //Posição deve estar zerada
           {
            if(isSinalCompra())
              {
                  
                  //Disparar ordem de compra
                  preco_stop_pos = candle[velas].low; 
                  preco_start_pos = ask_compra;
                  preco_alvo_pos = preco_start_pos + (preco_stop_pos - preco_start_pos) * retorno;

                  meutrade.Buy(lote,_Symbol,preco_start_pos,preco_stop_pos,preco_alvo_pos,
                     "Fechamento da vela rompeu a média movel indicando uma reversão de alta");
                     
                  if(saldo_pos < 0 && stop_loss >= ask_compra){ stop_count++; Print("Loss"); }

              }
            if(isSinalVenda())
              {
                  //Dispara ordem de venda
                  preco_stop_pos = candle[velas].high;
                  preco_start_pos = bid_venda;
                  preco_alvo_pos = preco_start_pos - (preco_stop_pos - preco_start_pos) * retorno;
                  
                  meutrade.Sell(lote,_Symbol,preco_start_pos,preco_stop_pos,preco_alvo_pos,
                     "Fechamento da candlerompeu a média movel indicando uma reversão de baixa");
                  
                  if(saldo_pos < 0 && stop_loss <= bid_venda){ stop_count++; Print("Loss");}
              }
           }
         else
            if(isComprado)
              {
                  //Ajustar o stop
                  preco_alvo_pos = preco_start_pos + (preco_stop_pos - preco_start_pos)*retorno; //Manter o preço alvo aberto
                  preco_stop_pos = candle[velas].low; 
                  if(trailling_stop){  meutrade.PositionModify(_Symbol,preco_stop_pos,preco_alvo_pos);   }
                  
              } 
            else
               if(isVendido)
                 {
                  //Ajustar o stop
                  preco_alvo_pos =  preco_start_pos - (preco_stop_pos - preco_start_pos)*retorno; //Manter o preço alvo aberto
                  preco_stop_pos = candle[velas].high;
                  if(trailling_stop){  meutrade.PositionModify(_Symbol,preco_stop_pos,preco_alvo_pos);   }

                 }
        }
      else
        {//Instruções a fazer quando excede o horário do pregão
        
         stop_count = 0;  //Trades realizados por dia

         if(isComprado)
           {
            meutrade.Sell(1,_Symbol,0,0,0,"Venda zerar posição");
           }
         if(isVendido)
           {
            meutrade.Buy(1,_Symbol,0,0,0,"Compra zerar posição");
           }
        }
     }
  }


   
   //Funcionalidade: Identificar horário de operação
   bool isHorarioNegociacao()
     {
      bool condicao = false;
   
      MqlDateTime mqldt;
      TimeCurrent(mqldt);
   
      int hora = mqldt.hour;
      int minuto = mqldt.min;
   
   //Zeragem compulsória pelo robô
      if(hora >= hora_abertura && minuto >=minuto_abertura)
         if(hora <= hora_encerramento && minuto >=minuto_encerramento)
            condicao = true;
   
      return condicao;
     }
   
   
   
   //+------------------------------------------------------------------+
   //|  Gatilhos de entrada 9.1                                         |
   //+------------------------------------------------------------------+
   bool isSinalCompra()
     {
         bool sinal = false;

         //Dados das velas devem estar capturados
   
         //if(touros <= velas)   //As velas anteriores devem fechar abaixo da média móvel
            if((candle[1].close > mmexponencial[1]) && (candle[1].close > candle[1].open) )//candlede alta que rompeu a media movel
                  if( mmexponencial[2] > candle[2].open  )//Penultima candleque não fechou a máxima acima da média movel
                     { sinal = true; }
                     
         return sinal;
      }

   bool isSinalVenda()
     {
      
         bool sinal = false;
         
         //Dados das velas devem estar capturados
         
         //if(touros >= velas)   //As velas anteriores devem fechar acima da média móvel(touro)
            if((candle[1].close < mmexponencial[1]) && (candle[1].close < candle[1].open) )//Ultimas velas devem ser de baixa e romper a média movel
                  if(candle[2].low > mmexponencial[2])  //Penultima candlefechou com a minima acima de média movel
                     { sinal = true;  }
                     
                         
      return sinal;
     }

   bool isNovaVela()
     {
   //--- memorize the time of opening of the last bar in the static variable
      static datetime last_time=0;
   //--- current time
      datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   
   //--- if it is the first call of the function
      if(last_time==0)
        {
         //--- set the time and exit
         last_time=lastbar_time;
         return(false);
        }
   
   //--- if the time differs
      if(last_time!=lastbar_time)
        {
         //--- memorize the time and return true
         last_time=lastbar_time;
         return(true);
        }
   //--- if we passed to this line, then the bar is not new; return false
      return(false);
     }
   //+------------------------------------------------------------------+
