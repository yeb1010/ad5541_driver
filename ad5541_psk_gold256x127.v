module ad5541_psk_gold256x127(

clk_10m,
rst_n,
i_code_sel1,
i_code_sel2,
i_code_sel3,
i_code_sel4,
i_contious,

sclk,
mosi,
cs

    );

input       clk_10m;
input       rst_n;
input [7:0]i_code_sel1;        //输入码元段1选择信号
input [7:0]i_code_sel2;
input [7:0]i_code_sel3;
input [7:0]i_code_sel4;
input       i_contious;         //输入是否连续发送帧 信号


output    reg  sclk;
output    reg  mosi;
output    reg   cs  ;


parameter  IDLE = 3'b000;
parameter  PRE_WRITE= 3'b001;
parameter  WRITE= 3'b010;
parameter  DELAY= 3'b011;
parameter  ONE_WRITE_DONE = 3'b100;
parameter  FRAME_DONE = 3'b101;

//reg [15:0] code_sel1;
//reg [15:0] code_sel2;
//reg [15:0] code_sel3; 


reg [2:0] state;
reg [15:0] cnt_spi;
reg [15:0] cnt_data_delay;
reg [15:0] cnt_da_nums;
reg [3:0] cnt_code_nums;
reg [19:0] cnt_frame_delay;



parameter CNT_DELAY=165;  //数据更新到da完全读取需要3.2us(状态2持续时间)，
                            //10mhz时钟一个周期为100ns,状态3持续时间为CNT_DELAY*100ns
                            //状态0、1、4共耗时300ns，则一共耗时3500ns＋CNT_DELAY*100ns；
parameter DA_NUMS=1524; 
 
parameter FRAME_DELAY = 200000; //若连续发送，每帧之间间隔20ms
 
 
        
 
always@(posedge clk_10m)
    if(!rst_n)
        state<=IDLE;
    else case(state)
            IDLE: state<=PRE_WRITE;
            
            PRE_WRITE:state<=WRITE;
            
            WRITE:  begin
                        if(cnt_spi==31)
                            state<=DELAY;
                        else
                            state<=WRITE;
                    end   
            DELAY:  begin
            
                    if(cnt_data_delay==CNT_DELAY-1)
                        state<=ONE_WRITE_DONE;
                    else
                        state<=DELAY;
                    end
                    
            ONE_WRITE_DONE:begin
                    if((cnt_code_nums==10)&&(cnt_da_nums==DA_NUMS-1))     //若一帧发送完毕，则进入FRAME_DONE状态
                        state<=FRAME_DONE;
                    else
                        state<=IDLE;
                    end    
            FRAME_DONE:begin
                    if(i_contious)         //若是连续发送，则在间隔frame_delay回到IDLE状态继续准备发送
                        if(cnt_frame_delay==FRAME_DELAY-1)
                            state<=IDLE;  
                        else
                            state<=FRAME_DONE;
                    else                 //否则就在FRAME_DONE状态等待rst_n拉低后再拉高
                        state<=FRAME_DONE;
                            
                    end    
  
                    
            default:state<=IDLE;
        
        endcase


always@(posedge clk_10m)         //cnt_spi计数
    if(!rst_n)
        cnt_spi<=0;
    else if(state==WRITE)
        if(cnt_spi==31)
            cnt_spi<=0;
        else
            cnt_spi<=cnt_spi+1;
            
    else
        cnt_spi<=0;
            
always@(posedge clk_10m) //cnt_data_delay计数。一个数据写入5541后的延时
    if(!rst_n)
        cnt_data_delay<=0;
    else if(state==DELAY)
        if(cnt_data_delay==CNT_DELAY-1)
            cnt_data_delay<=0;
        else
            cnt_data_delay<=cnt_data_delay+1;
    else
        cnt_data_delay<=0;

        
always@(posedge clk_10m)
    if(!rst_n)
        cs<=1;
    else if((state==PRE_WRITE)||(state==WRITE)) //提前将cs信号拉低
        cs<=0;
    else
        cs<=1;

always@(posedge clk_10m)              //cnt_da_nums计数
    if(!rst_n)
        cnt_da_nums<=0;
    else if(state==ONE_WRITE_DONE)begin
        if(cnt_da_nums==DA_NUMS-1)
            cnt_da_nums<=0;
        else 
            cnt_da_nums<=cnt_da_nums+1;
        end
    else
        cnt_da_nums<=cnt_da_nums;
        
always@(posedge clk_10m)       //code_nums计数
    if(!rst_n)
        cnt_code_nums<=0;
    else if(state==ONE_WRITE_DONE)
        if((cnt_code_nums==10)&&(cnt_da_nums==DA_NUMS-1))
            cnt_code_nums<=0;
        else if(cnt_da_nums==DA_NUMS-1)
            cnt_code_nums<=cnt_code_nums+1;
    else
        cnt_code_nums<=cnt_code_nums;



always@(posedge clk_10m)       //frame_delay计数
    if(!rst_n)
        cnt_frame_delay<=0;
    else if(state==FRAME_DONE)
        if(cnt_frame_delay==FRAME_DELAY-1)
            cnt_frame_delay<=0;
        else    
            cnt_frame_delay<=cnt_frame_delay+1;
    
reg [15:0] samples_data;

reg [7:0]cnt_12,cnt_127;    

reg [15:0] rom_data; 

wire [15:0] sin_frame_data;
reg[11:0] sin_frame_addra;

wire [126:0] gold_code;
reg[7:0] gold_code_addra;

wire [15:0] samples0_rom_data;
wire [15:0] samples1_rom_data;

parameter SAMPLES01_NUMS = 12;

sin_frame sin_frame (
  .clka(clk_10m),    // input wire clka
  .addra(sin_frame_addra),  // input wire [10 : 0] addra
  .douta(sin_frame_data)  // output wire [15 : 0] douta
);

gold_code127x1024 gold_code256x127 (
  .clka(clk_10m),    // input wire clka
  .addra(gold_code_addra),  // input wire [9 : 0] addra
  .douta(gold_code)  // output wire [126 : 0] douta
);

samples0_rom samples0_rom (
  .clka(clk_10m),    // input wire clka
  .addra(cnt_12),  // input wire [3 : 0] addra
  .douta(samples0_rom_data)  // output wire [15 : 0] douta
);

samples1_rom samples1_rom (
  .clka(clk_10m),    // input wire clka
  .addra(cnt_12),  // input wire [3 : 0] addra
  .douta(samples1_rom_data)  // output wire [15 : 0] douta
);

always@(posedge clk_10m)
    if(!rst_n)
        sin_frame_addra<=0;                   //sin_frame_addra
    else if(state==DELAY)
        begin
        if(cnt_data_delay==CNT_DELAY-5)begin //提前更新addra
            if(cnt_code_nums==0)begin
                if(cnt_da_nums==DA_NUMS-1)            
                    sin_frame_addra<=0;
                else
                    sin_frame_addra<=sin_frame_addra+1;
                end
            end    
        end               
    else 
        sin_frame_addra<=sin_frame_addra;
      
 
always@(posedge clk_10m)
    if(!rst_n)
        gold_code_addra<=0;
    else if(state==DELAY)
            if(cnt_data_delay==CNT_DELAY-5)
                case(cnt_code_nums)
                2:gold_code_addra<=0;

                4:gold_code_addra<=i_code_sel1-1;

                6:gold_code_addra<=i_code_sel2-1;

                8:gold_code_addra<=i_code_sel3-1;
                
                10:gold_code_addra<=i_code_sel4-1;
                default:gold_code_addra<=gold_code_addra;
                endcase



always@(posedge clk_10m)
    if(!rst_n)begin
        cnt_12<=0;
    end
    else if(state==ONE_WRITE_DONE)
        if ((cnt_code_nums==2)||(cnt_code_nums==4)||(cnt_code_nums==6)||(cnt_code_nums==8)||(cnt_code_nums==10))
           if(cnt_12==SAMPLES01_NUMS-1) begin
                cnt_12<=0;
                end
            else
                cnt_12<=cnt_12+1;

                
always@(posedge clk_10m)
    if(!rst_n)begin
        cnt_127<=0;
    end
    else if(state==ONE_WRITE_DONE)
        if ((cnt_code_nums==2)||(cnt_code_nums==4)||(cnt_code_nums==6)||(cnt_code_nums==8)||(cnt_code_nums==10))                
            if((cnt_127==127-1)&&(cnt_12==SAMPLES01_NUMS-1))
                cnt_127<=0;
            else if(cnt_12==SAMPLES01_NUMS-1)
                cnt_127<=cnt_127+1;
 
always@(posedge clk_10m)
    if(!rst_n)
       samples_data<=0;
    else if(state==PRE_WRITE)
        case (cnt_code_nums)
            2: begin
                if(gold_code[cnt_127]==0)
                    samples_data<=samples0_rom_data;
                else
                    samples_data<=samples1_rom_data;
              end
            
            4:begin
                if(gold_code[cnt_127]==0)
                    samples_data<=samples0_rom_data;
                else
                    samples_data<=samples1_rom_data;
              end
            
            6:begin
                if(gold_code[cnt_127]==0)
                    samples_data<=samples0_rom_data;
                else
                    samples_data<=samples1_rom_data;
              end
            
            8:begin
                if(gold_code[cnt_127]==0)
                    samples_data<=samples0_rom_data;
                else
                    samples_data<=samples1_rom_data;
              end
            
            10:begin
                if(gold_code[cnt_127]==0)
                    samples_data<=samples0_rom_data;
                else
                    samples_data<=samples1_rom_data;
              end
            
            default:samples_data<=samples_data;
        
        endcase


    
always@(posedge clk_10m)
    if(!rst_n)
        rom_data<=sin_frame_data;
    else if(state==ONE_WRITE_DONE)begin
        case (cnt_code_nums)
            0:rom_data<=sin_frame_data;
            1:rom_data<=0;
            2:rom_data<=samples_data;
            3:rom_data<=0;
            4:rom_data<=samples_data;
            5:rom_data<=0;
            6:rom_data<=samples_data;
            7:rom_data<=0;
            8:rom_data<=samples_data;
            9:rom_data<=0;
            10:rom_data<=samples_data;
            default:rom_data<=0;
        
        endcase

        end
            
        


always@(posedge clk_10m)
    if(!rst_n)
        begin
        sclk<=1;
        mosi<=1;      
        end
    else if(state==WRITE)
        begin
            case(cnt_spi)
                0: begin
                    mosi<=rom_data[15];
                    sclk<=0;                    
                    end
                2: begin
                   mosi<=rom_data[14];
                   sclk<=0; 
                   end
                4: begin
                   mosi<=rom_data[13];
                   sclk<=0; 
                   end
                6: begin
                   mosi<=rom_data[12];
                   sclk<=0; 
                   end
                8: begin
                   mosi<=rom_data[11];
                   sclk<=0; 
                   end
                10: begin
                   mosi<=rom_data[10];
                   sclk<=0; 
                   end
                12: begin
                   mosi<=rom_data[9];
                   sclk<=0; 
                   end
                14: begin
                   mosi<=rom_data[8];
                   sclk<=0; 
                   end
                16: begin
                   mosi<=rom_data[7];
                   sclk<=0; 
                   end
                18: begin
                   mosi<=rom_data[6];
                   sclk<=0; 
                   end
                20: begin
                   mosi<=rom_data[5];
                   sclk<=0; 
                   end
                22: begin
                   mosi<=rom_data[4];
                   sclk<=0; 
                   end
                24: begin
                   mosi<=rom_data[3];
                   sclk<=0; 
                   end   
                26: begin
                   mosi<=rom_data[2];
                   sclk<=0; 
                   end   
                28: begin
                   mosi<=rom_data[1];
                   sclk<=0; 
                   end
                30: begin
                   mosi<=rom_data[0];
                   sclk<=0; 
                   end
                default:begin
                        
                        sclk<=1;
                        end
            endcase
        
        
        end
    else
        begin
        mosi<=1;
        sclk<=1;
        end





endmodule
