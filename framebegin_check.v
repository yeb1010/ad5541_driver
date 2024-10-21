`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/18 15:02:16
// Design Name: 
// Module Name: framebegin_check
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:

// create by yeb  @_@ @@_@@

//////////////////////////////////////////////////////////////////////////////////


module framebegin_check(

clk,

checkbegin_flag,
fifo7768_data,
sin_yuzhi,
code1_xcor_yuzhi,
pn_xcor_yuzhi,

fifo7768_rden,
fifo7768_rdclk,
fifo7768_refresh,
frame_check_end,
frame_code_jiegou,
frame_noresult


    );
    
input clk;
input [47:0]sin_yuzhi;
 (* mark_debug="true" *)input checkbegin_flag;
(* mark_debug="true" *) input [23:0] fifo7768_data;    
input [10:0]   code1_xcor_yuzhi ;
input [10:0]   pn_xcor_yuzhi;
    
    
(* mark_debug="true" *) output fifo7768_rdclk;
(* mark_debug="true" *) output reg fifo7768_rden;
(* mark_debug="true" *) output reg fifo7768_refresh;
output reg frame_check_end;
output reg [31:0] frame_code_jiegou;
(* mark_debug="true" *)output reg frame_noresult;

reg rstn=0;

always@(posedge fifo7768_rdclk)begin
        rstn    <=  checkbegin_flag;

end


parameter sqrt_Rss0_2_dimi65536 =   'd779075; 
parameter sqrt_R110_2_dimi65536 =   'd673972;
parameter sqrt_R220_2_dimi65536 =   'd667682;
parameter sqrt_R330_2_dimi65536 =   'd671842;
parameter sqrt_R440_2_dimi65536 =   'd667057;
parameter sqrt_R550_2_dimi65536 =   'd672069;
parameter sqrt_R660_2_dimi65536 =   'd670422;
parameter sqrt_R770_2_dimi65536 =   'd671759;
parameter sqrt_R880_2_dimi65536 =   'd665549;
parameter sqrt_R990_2_dimi65536 =   'd667909;
parameter sqrt_R10100_2_dimi65536 = 'd673141;
parameter sqrt_R11110_2_dimi65536 = 'd665967;
parameter sqrt_R12120_2_dimi65536 = 'd668389;
parameter sqrt_R13130_2_dimi65536 = 'd669319;
parameter sqrt_R14140_2_dimi65536 = 'd665930;
parameter sqrt_R15150_2_dimi65536 = 'd675784;
parameter sqrt_R16160_2_dimi65536 = 'd665720;

parameter IDLE = 'd0;
parameter FRAME_SINCHECK0 = 'd1;
parameter FRAME_SINCHECK1 = 'd2;
parameter FRAME_SINXOR    = 'd3;
parameter FRAME_SIN_DELAY = 'd4;
parameter DELAY1 = 'd5;

parameter FRAME_CODE1CHECK0 = 'd6;
parameter FRAME_CODE1CHECK1 = 'd7;
parameter FRAME_CODE1XOR    =   'd8;
parameter FRAME_CODE1_DELAY    = 'd9;

parameter FRAME_P2CHECK    = 'd10;
parameter FRAME_P2XOR       = 'd11;
parameter FRAME_P2DELAY    = 'd12;

parameter FRAME_P3CHECK    = 'd13;
parameter FRAME_P3XOR       = 'd14;
parameter FRAME_P3DELAY    = 'd15;

parameter FRAME_P4CHECK    = 'd16;
parameter FRAME_P4XOR       = 'd17;
parameter FRAME_P4DELAY    = 'd18;

parameter FRAME_P5CHECK    = 'd19;
parameter FRAME_P5XOR       = 'd20;
parameter FRAME_P5DELAY    = 'd21;

parameter FRAME_END         =   'd255;

 (* mark_debug="true" *)reg [15:0] rd_data_cnt;
(* mark_debug="true" *) reg [15:0] cnt_15240=0;


(* mark_debug="true" *) reg [7:0] state;

reg [3:0] cnt_rstn;

(* mark_debug="true" *)reg sin_10khz_h = 0;

(* mark_debug="true" *)reg frame_sin10khz_cfm=0;
reg frame_sin_ncfm=0;
(* mark_debug="true" *)reg frame_code1_cfm=0; 
(* mark_debug="true" *)reg frame_code1_ncfm=0;


(* mark_debug="true" *) reg [7:0]frame_p2jiegou=0;
(* mark_debug="true" *) reg [7:0]frame_p3jiegou=0;
(* mark_debug="true" *) reg [7:0]frame_p4jiegou=0;
(* mark_debug="true" *) reg [7:0]frame_p5jiegou=0;



//定义数据参数

// MAXMAX: 9532724480000
wire [47:0]SIN_MAX;
wire [10:0] CODE1_XCOR_MAX;
wire [10:0] Pn_XCOR_MAX;
assign SIN_MAX   =   sin_yuzhi;            //确定粗同步帧头的触发阈值
assign CODE1_XCOR_MAX = code1_xcor_yuzhi;  //细同步帧头的相关函数阈值
assign Pn_XCOR_MAX = pn_xcor_yuzhi;        //其它位置码元段的相关函数阈值
    
parameter FIFO7768_FRAMEHALF_MAX = 'd14000;
parameter RD_DATA_CNT_MAX = 'd2048;          //7768fifo 数据读出后 fft 变换长度
parameter CODE_DELAY_MAX = 'd1494;      //读取码元段间隔0 与某code左右 多读的长度有关
parameter ONECODE_XOR_FIFOLEN = 'd1544; //比码元段长度多20，多读20个数据，前后各10个，确保包含code 码元 
parameter SINCHECK_HALF_MAX = 'd772;        // 粗同步帧头sin 检测时 读一半存一半 长度
parameter CODE1CHECK_HALFFIFO_MAX = 'd1524;  // 细同步帧头检测时，每次移动20个数据，则有这么多个数据存入fifo
parameter CODE1_CHECK_SHIFT_NUM = 'd20;      //细同步帧头 检测时，每次移动这么多个数据



assign fifo7768_rdclk   =   clk;

// 发送帧结构： sin——code0——P2——P3——P4-p5  （ —— 代表间隔0） 固定发送码元段0作为细同步帧头，发送码元段从0x00到0xff



always@(posedge fifo7768_rdclk)begin
    if(!rstn)begin
        state   <=  IDLE;
        fifo7768_refresh    <=  0;
        end
    else case(state)
            IDLE:   begin                   // 0
                if(cnt_15240<=FIFO7768_FRAMEHALF_MAX)begin   //FIFO7768_FRAMEHALF_MAX = 15240
                    state  <=  FRAME_SINCHECK0; 
                    fifo7768_refresh    <=  0;
                    end
                else begin     
                    state   <=  IDLE;
                    fifo7768_refresh    <=  1;
                    end
                
                end
            FRAME_SINCHECK0:begin                   //1
                    if(rd_data_cnt==2048)
                        state <=  FRAME_SINXOR;
                    else
                        state <=    FRAME_SINCHECK0;
                end
            
            FRAME_SINXOR:begin                     //3                 
                    if(frame_sin10khz_cfm)
                        state   <=  DELAY1;
                    else if(frame_sin_ncfm)
                        state   <=  DELAY1;
                
                end
            
            DELAY1:begin                        // 5 sin_fft ip核 复位
                   if(cnt_rstn>=7 && frame_sin_ncfm) 
                        state   <=  FRAME_SINCHECK1;
                   else if(cnt_rstn>=7 && frame_sin10khz_cfm)begin
                        state   <=  FRAME_SIN_DELAY;
                   end
                        
                   else
                        state   <=  state;
                end
                
                
            FRAME_SINCHECK1:begin                  //2
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_SINXOR;
                    else if(cnt_15240>=FIFO7768_FRAMEHALF_MAX)
                        state   <=  IDLE;
                
                end
           FRAME_SIN_DELAY:begin                 //4 间隔1524点
                    if(rd_data_cnt==1494)
                        state   <=  FRAME_CODE1CHECK0;
                    else 
                        state   <=  state;           
                end
            
          FRAME_CODE1CHECK0:begin        //6
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_CODE1XOR;
                    else
                        state   <=  state;
                end
          
          
          FRAME_CODE1XOR:begin         //8
                    if(frame_code1_cfm)
                        state   <=  FRAME_CODE1_DELAY;
                    else if(frame_code1_ncfm)
                        state   <=  FRAME_CODE1CHECK1;
                
                end
          
          FRAME_CODE1CHECK1:begin       //7
                    if(rd_data_cnt==2049)
                        state   <=  FRAME_CODE1XOR;
                    else if(cnt_15240>=FIFO7768_FRAMEHALF_MAX+2000)
                        state   <=  IDLE;
                end
                
          FRAME_CODE1_DELAY:begin   //9
                   if(rd_data_cnt==1494)
                        state   <=  FRAME_P2CHECK;
                   else
                        state   <=  state;
                
                end
          
          
          FRAME_P2CHECK: begin //10           
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_P2XOR;
                    else 
                        state   <=  state;
                end
         
          FRAME_P2XOR:begin   //11         
                    if(frame_p2jiegou!=0)
                        state   <=  FRAME_P2DELAY;
                    else 
                        state   <=  state;
                end
          
          FRAME_P2DELAY:begin   //12
                if(rd_data_cnt==1494)
                    state   <=  FRAME_P3CHECK;
                else
                    state   <=  state;
                end
          
          FRAME_P3CHECK:begin     //13     
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_P3XOR;
                    else 
                        state   <=  state;
                end
                
          FRAME_P3XOR:begin        //14   
                    if(frame_p3jiegou!=0)
                        state   <=  FRAME_P3DELAY;
                    else 
                        state   <=  state;
                    
                end
                
          FRAME_P3DELAY:begin   //15
                if(rd_data_cnt==1494)
                    state   <=  FRAME_P4CHECK;
                else
                    state   <=  state;                
                end
          
          
          FRAME_P4CHECK:begin      //16    
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_P4XOR;
                    else 
                        state   <=  state;
                end
                
          FRAME_P4XOR:begin         //17
                    if(frame_p4jiegou!=0)
                        state   <=  FRAME_P4DELAY;
                    else 
                        state   <=  state;
                    
                end
                
          FRAME_P4DELAY:begin       //18
                if(rd_data_cnt==1494)
                    state   <=  FRAME_P5CHECK;
                else
                    state   <=  state;                
                end
                
          FRAME_P5CHECK:begin       //19    
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_P5XOR;
                    else 
                        state   <=  state;
                end
                
          FRAME_P5XOR:begin         //20    
                    if(frame_p5jiegou!=0)
                        state   <=  FRAME_END;
                    else 
                        state   <=  state;
                    
                end
        
        FRAME_END:begin             
                state <=  state;      
                end
            default:state<=IDLE;
        
        endcase
       

end


reg [4:0] state_r;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        state_r <=  0;
    else
        state_r <=  state;

end


always@(posedge fifo7768_rdclk)begin     // fifo7768 读取数据计数
    if(!rstn)
        cnt_15240   <=  0;
/*     else if((state==IDLE)&&(cnt_15240   >=  16000))
        cnt_15240   <=  0; */
    else if(fifo7768_rden)
        cnt_15240   <=  cnt_15240+1;
        
end


always@(posedge fifo7768_rdclk)begin    // 检测结束信号
    if(!rstn)
        frame_check_end <=  0;
    else if(state==FRAME_END)
        frame_check_end <=  1;
    else
        frame_check_end <=  0;
end


      
always@(posedge fifo7768_rdclk)begin     //确定帧的结构
    if(!rstn)
        frame_code_jiegou <=  0;
    else if(state==FRAME_END)
        frame_code_jiegou <=  {frame_p2jiegou,frame_p3jiegou,frame_p4jiegou,frame_p5jiegou};
    else
        frame_code_jiegou <=  0;
end


 reg fifo7768_half_wren;
 reg fifo7768_half_rden;
    
always@(posedge fifo7768_rdclk )begin
    if(!rstn)begin
        fifo7768_half_rden  <=  0;
        fifo7768_rden   <=  0;
        end
    else if(state==FRAME_SINCHECK0)begin
        if(0<= rd_data_cnt && rd_data_cnt<=1543)
            fifo7768_rden   <=  1;
        else 
            fifo7768_rden   <=  0;
        end
        
    else if(state==FRAME_SINCHECK1)begin
        if(0<=rd_data_cnt && rd_data_cnt<=771)begin
            fifo7768_half_rden  <= 1;
            fifo7768_rden      <=  0;
            end
        else if(772<=rd_data_cnt && rd_data_cnt<=1543)begin
            fifo7768_rden       <=  1;
            fifo7768_half_rden <=  0;
            end
        else begin
             fifo7768_half_rden <=  0;
             fifo7768_rden      <=   0;
             end
        end

    else if(state==FRAME_SIN_DELAY)begin  //读取7768fifo 中的码元段间隔0
        if(0<=rd_data_cnt && rd_data_cnt<=1493)
            fifo7768_rden   <=  1;
        end
    
    else if(state==FRAME_CODE1_DELAY)begin  //读取7768fifo 中的码元段间隔0
        if(0<=rd_data_cnt && rd_data_cnt<=1493)
            fifo7768_rden   <=  1;
        end

    else if(state==FRAME_CODE1CHECK0)begin
        if(0<= rd_data_cnt && rd_data_cnt<=1543)
            fifo7768_rden   <=  1;
        else 
            fifo7768_rden   <=  0;
        end    
    else if(state==FRAME_CODE1CHECK1)begin
        if(0<=rd_data_cnt && rd_data_cnt<=1522)begin
            fifo7768_half_rden  <= 1;
            fifo7768_rden      <=  0;
            end
        
        else if(rd_data_cnt==1523)begin
            fifo7768_half_rden  <= 0;
            fifo7768_rden      <=  0;            
        
        end
        
        else if(1524<=rd_data_cnt && rd_data_cnt<=1543)begin
            fifo7768_rden       <=  1;
            fifo7768_half_rden <=  0;
            end
        else begin
             fifo7768_half_rden <=  0;
             fifo7768_rden      <=   0;
             end
        end
    
    else if(state==FRAME_P2CHECK)begin
        if(0 <= rd_data_cnt && rd_data_cnt <= 1543)
            fifo7768_rden   <=  1;
        else
            fifo7768_rden   <=  0;
    end

    else if(state==FRAME_P2DELAY)begin  //读取7768fifo 中的码元段间隔0
        if(0<=rd_data_cnt && rd_data_cnt<=1493)
            fifo7768_rden   <=  1;
        end
    
    else if(state==FRAME_P3CHECK)begin
        if(0 <= rd_data_cnt && rd_data_cnt <= 1543)
            fifo7768_rden   <=  1;
        else 
            fifo7768_rden   <=  0;
    end

    else if(state==FRAME_P3DELAY)begin  //读取7768fifo 中的码元段间隔0
        if(0<=rd_data_cnt && rd_data_cnt<=1493)
            fifo7768_rden   <=  1;
    end
    
    else if(state==FRAME_P4CHECK)begin
        if(0 <= rd_data_cnt && rd_data_cnt <= 1543)
            fifo7768_rden   <=  1;
        else 
            fifo7768_rden   <=  0;
        
    end

    else if(state==FRAME_P4DELAY)begin  //读取7768fifo 中的码元段间隔0
        if(0<=rd_data_cnt && rd_data_cnt<=1493)
            fifo7768_rden   <=  1;
    end
        
    else if(state==FRAME_P5CHECK)begin
        if(0 <= rd_data_cnt && rd_data_cnt <= 1543)
            fifo7768_rden   <=  1;
        else 
            fifo7768_rden   <=  0;
        
    end
 
    else begin
        fifo7768_rden   <=  0;
        fifo7768_half_rden  <=  0;
        end

end



reg [23:0] s_fft_re_data;
wire  [23:0] fifo7768_half_dout;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        rd_data_cnt <=  0;
    else if(state==FRAME_SINCHECK0)begin
        if(rd_data_cnt==2048)
            rd_data_cnt <=  0;
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <=  fifo7768_data;
            end
        else if(1543<=rd_data_cnt   &&  rd_data_cnt<=2047)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <= 0;
            end
        end
   
   else if(state==FRAME_SINCHECK1)begin
        if(rd_data_cnt==2048)
            rd_data_cnt<=0;
        else if(fifo7768_half_rden)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <=  fifo7768_half_dout;            
            end
        
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <=  fifo7768_data;             
            
            end
        
        else if(1543<=rd_data_cnt   &&  rd_data_cnt<=2047)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <= 0;
 
            end            
        end

    else if(state==FRAME_SIN_DELAY)begin
        if(rd_data_cnt==1494)
            rd_data_cnt <=  0;
        else if(fifo7768_rden)
            rd_data_cnt <=  rd_data_cnt+1;
    end

    else if(state==FRAME_CODE1_DELAY)begin
        if(rd_data_cnt==1494)
            rd_data_cnt <=  0;
        else if(fifo7768_rden)
            rd_data_cnt <=  rd_data_cnt+1;
    end
    
    else if(state==FRAME_CODE1CHECK0)begin
        if(rd_data_cnt==2048)
            rd_data_cnt <=  0;
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <=  fifo7768_data;
            end
        else if(1543<=rd_data_cnt   &&  rd_data_cnt<=2047)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <= 0;
            end
        end
   
   else if(state==FRAME_CODE1CHECK1)begin
        if(rd_data_cnt==2049)//2049
            rd_data_cnt<=0;
        else if((fifo7768_half_rden)||(rd_data_cnt==1524))begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <=  fifo7768_half_dout;            
            end
        
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <=  fifo7768_data;             
            
            end
        
        else if(1544<=rd_data_cnt   &&  rd_data_cnt<=2048)begin
            rd_data_cnt <=  rd_data_cnt+1;
            s_fft_re_data    <= 0;
 
            end            
        end
    
    else if(state==FRAME_P2CHECK)begin
        if(rd_data_cnt==2048)
            rd_data_cnt <=  0;
            
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  fifo7768_data;       
        end
        
        else if(1543 <= rd_data_cnt && rd_data_cnt <= 2047)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  0;        
        end
        
    end

    else if(state==FRAME_P2DELAY)begin
        if(rd_data_cnt==1494)
            rd_data_cnt <=  0;
        else if(fifo7768_rden)
            rd_data_cnt <=  rd_data_cnt+1;
    end

    else if(state==FRAME_P3CHECK)begin
        if(rd_data_cnt==2048)
            rd_data_cnt <=  0;
            
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  fifo7768_data;       
        end
        
        else if(1543 <= rd_data_cnt && rd_data_cnt <= 2047)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  0;        
        end  
        
    end
    else if(state==FRAME_P3DELAY)begin
        if(rd_data_cnt==1494)
            rd_data_cnt <=  0;
        else if(fifo7768_rden)
            rd_data_cnt <=  rd_data_cnt+1;
    end

    else if(state==FRAME_P4CHECK)begin
        if(rd_data_cnt==2048)
            rd_data_cnt <=  0;
            
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  fifo7768_data;       
        end
        
        else if(1543 <= rd_data_cnt && rd_data_cnt <= 2047)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  0;        
        end          
    end
    else if(state==FRAME_P4DELAY)begin
        if(rd_data_cnt==1494)
            rd_data_cnt <=  0;
        else if(fifo7768_rden)
            rd_data_cnt <=  rd_data_cnt+1;
    end

    else if(state==FRAME_P5CHECK)begin
        if(rd_data_cnt==2048)
            rd_data_cnt <=  0;
            
        else if(fifo7768_rden)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  fifo7768_data;       
        end
        
        else if(1543 <= rd_data_cnt && rd_data_cnt <= 2047)begin
            rd_data_cnt <=  rd_data_cnt +   1;
            s_fft_re_data   <=  0;        
        end          
    end   
end    


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fifo7768_half_wren  <=  0;
    else if(state==FRAME_SINCHECK0||state==FRAME_SINCHECK1)begin
        if(772<=rd_data_cnt && rd_data_cnt<=1543) // 第773 到 第1524个数据 
            fifo7768_half_wren  <=  1;
        else 
            fifo7768_half_wren  <=  0;
    end        
    
    else if(state==FRAME_CODE1CHECK0||state==FRAME_CODE1CHECK1)begin
        if(20<=rd_data_cnt && rd_data_cnt<=1543) // 第21 到 第1544个数据 
            fifo7768_half_wren  <=  1;
        else 
            fifo7768_half_wren  <=  0;        
    
    end
    
    else
        fifo7768_half_wren  <=  0;
end

reg fifo7768_half_rst;
always@(posedge fifo7768_rdclk)begin    //fifo7768_half  复位，高电平有效。检出sin 后复位ip 核，在code1_check 复用
    if(!rstn)
        fifo7768_half_rst   <=  1;
    else if(state==DELAY1)begin
        if(frame_sin10khz_cfm)
            fifo7768_half_rst   <=  1;
        else
            fifo7768_half_rst   <=  0;
        end
    else
        fifo7768_half_rst   <=  0;

end

reg [23:0] fifo7768_half_dindata;

always@(*)begin
    if(!rstn)
        fifo7768_half_dindata   <=  0;
    else if((state==FRAME_SINCHECK0)||(state==FRAME_SINCHECK1)||(state==FRAME_CODE1CHECK0))
        fifo7768_half_dindata   <=  fifo7768_data;
    else if(state==FRAME_CODE1CHECK1)begin 
         if(rd_data_cnt<=1524)
            fifo7768_half_dindata  <=  fifo7768_half_dout;
         else
            fifo7768_half_dindata  <=  fifo7768_data;
    end
end


fifo_generator_3 fifo7768_half (
  .clk(fifo7768_rdclk),      // input wire clk
  .srst(fifo7768_half_rst),    // input wire srst
  
  .din(fifo7768_half_dindata),      // input wire [23 : 0] din
  .wr_en(fifo7768_half_wren),  // input wire wr_en
  
  .rd_en(fifo7768_half_rden),  // input wire rd_en
  .dout(fifo7768_half_dout),    // output wire [23 : 0] dout
  
  .full(),    // output wire full
  .empty()  // output wire empty
);


    
wire  [47:0] s_fft_data; 
assign s_fft_data = {24'b0,s_fft_re_data};   
        

/*************   补零后进行 fft ************/      

reg s_frame_sin_check_data_tvalid=0;
reg  fifo7768_rden_r=0;

 wire [47:0] m_fft_frame_check_data;
 wire m_fft_frame_check_data_tvalid;
wire m_fft_frame_check_data_tlast;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fifo7768_rden_r <=  0;
    else 
        fifo7768_rden_r <=  fifo7768_rden;



end


reg s_frame_sin_check_data_tvalid_a;
always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        s_frame_sin_check_data_tvalid_a <=  0;
    else if(state==FRAME_CODE1CHECK1)
        if(fifo7768_half_rden)
        s_frame_sin_check_data_tvalid_a <=  1;
    else if(rd_data_cnt==2048)
        s_frame_sin_check_data_tvalid_a <=  0;

end


always@(posedge fifo7768_rdclk)begin    //7768fifo 出来数据 进行 fft ip核 输入信号有效控制 
    if(!rstn)
        s_frame_sin_check_data_tvalid <=  0;
    else if(state==FRAME_SINCHECK0)begin
        if(fifo7768_rden)
            s_frame_sin_check_data_tvalid   <=  1;
        else  if(rd_data_cnt==2048)   
            s_frame_sin_check_data_tvalid   <=  0;
    end
    
    else if(state==FRAME_SINCHECK1)begin
        if(fifo7768_half_rden)
            s_frame_sin_check_data_tvalid   <=  1;
        else if(rd_data_cnt==2048)
            s_frame_sin_check_data_tvalid   <=  0;
    end
    
    else if(state==FRAME_CODE1CHECK0)begin
        if(fifo7768_rden)
            s_frame_sin_check_data_tvalid   <=  1;
        else if(rd_data_cnt==2048)
            s_frame_sin_check_data_tvalid   <=  0;
    end

    else if(state==FRAME_CODE1CHECK1)begin
         s_frame_sin_check_data_tvalid    <=  s_frame_sin_check_data_tvalid_a;
    end    
    
    else if((state==FRAME_P2CHECK)||(state==FRAME_P3CHECK)||(state==FRAME_P4CHECK)||(state==FRAME_P5CHECK))begin
        if(fifo7768_rden)
            s_frame_sin_check_data_tvalid   <=  1;
        else if(rd_data_cnt==2048)
            s_frame_sin_check_data_tvalid   <=  0;
    end
    
    else
        s_frame_sin_check_data_tvalid   <=  0;

end



reg fft_frame_sin_check_rstn;


always@(posedge fifo7768_rdclk)begin           // fft fram_sin_check ip核的复位信号，
    if(!rstn)                                   //当状态变化时 复位ip核，丢弃还未输出的数据
        fft_frame_sin_check_rstn    <=  1;
    else if(1<=cnt_rstn && cnt_rstn<=5)
        fft_frame_sin_check_rstn    <=  0;
    else if(cnt_rstn>=6)
        fft_frame_sin_check_rstn    <=  1;

end

reg frame_code_cut_valid=0;
reg frame_code_cut_valid_r=0;

reg [15:0] cnt_m_fft_frame_check_data;

(* mark_debug="true" *)reg [7:0]   f_cnt;    
reg [7:0]   f_cnt_r;   


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_rstn    <=  0;
        
    else if(state_r!=state)
        cnt_rstn    <=  0;
    else if(f_cnt_r!=f_cnt)
        cnt_rstn    <=  0;
    else if((state==IDLE)&&(fifo7768_refresh==1))begin
        if(cnt_rstn>=7)
            cnt_rstn    <=  cnt_rstn;
        else 
            cnt_rstn    <=  cnt_rstn+1;
    end    
    
    else if(state==DELAY1)begin
        if(cnt_rstn>=7)
            cnt_rstn    <=  cnt_rstn;
        else 
            cnt_rstn    <=  cnt_rstn+1;
    end
    
    else if((state==FRAME_CODE1XOR)||(state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(cnt_m_fft_frame_check_data>=622)begin //code1xor pnxor  截断数据有效信号的下降沿复位ip核
            if(cnt_rstn>=7)
                cnt_rstn    <=  cnt_rstn;
            else 
                cnt_rstn    <=  cnt_rstn+1;
        end

    
end

//调试信号

wire event_frame_started;
wire event_tlast_unexpected;
wire event_tlast_missing;
wire event_status_channel_halt;
wire event_data_in_channel_halt;
wire event_data_out_channel_halt;

//调试信号end

xfft_1 frame_sin_check (
  .aclk(fifo7768_rdclk),                                                // input wire aclk
   .aresetn(fft_frame_sin_check_rstn),
  
  .s_axis_config_tdata(16'b000_011010101010_1),                  // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_fft_data),                      // input wire [47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_frame_sin_check_data_tvalid),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_fft_frame_check_data),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_fft_frame_check_data_tvalid),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_fft_frame_check_data_tlast),                      // output wire m_axis_data_tlast
  
  .event_frame_started(event_frame_started),                  // output wire event_frame_started
  .event_tlast_unexpected(event_tlast_unexpected),            // output wire event_tlast_unexpected
  .event_tlast_missing(event_tlast_missing),                  // output wire event_tlast_missing
  .event_status_channel_halt(event_status_channel_halt),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(event_data_in_channel_halt),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt(event_data_out_channel_halt)  // output wire event_data_out_channel_halt
);
 
 

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_m_fft_frame_check_data  <=  0;
    else if(state_r!=state)
        cnt_m_fft_frame_check_data  <=  0;
    else if(f_cnt_r!=f_cnt)
        cnt_m_fft_frame_check_data  <=  0;
    else if(m_fft_frame_check_data_tvalid)
        cnt_m_fft_frame_check_data  <=  cnt_m_fft_frame_check_data +1;

end
     

 
 
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/    
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/  
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/  
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/  


wire [23:0] m_fft_frame_check_data_re;
wire [23:0] m_fft_frame_check_data_im;

assign m_fft_frame_check_data_re=m_fft_frame_check_data[23:0];
assign m_fft_frame_check_data_im=m_fft_frame_check_data[47:24];


wire [47:0] fft_sin_abs2_re2part;
wire [47:0] fft_sin_abs2_im2part;

wire mult_gen_sincut_abs2_valid;
assign  mult_gen_sincut_abs2_valid = (state==FRAME_SINXOR)? m_fft_frame_check_data_tvalid : 0;


mult_gen_sincut_abs2 fft_sin_abs2_re2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_fft_frame_check_data_re),      // input wire [23 : 0] A
  .B(m_fft_frame_check_data_re),      // input wire [23 : 0] B
  .CE(mult_gen_sincut_abs2_valid),    // input wire CE
   
   .P(fft_sin_abs2_re2part)      // output wire [47 : 0] P
);


mult_gen_sincut_abs2 fft_sin_abs2_im2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_fft_frame_check_data_im),      // input wire [23 : 0] A
  .B(m_fft_frame_check_data_im),      // input wire [23 : 0] B
  .CE(mult_gen_sincut_abs2_valid),    // input wire CE
   
   .P(fft_sin_abs2_im2part)      // output wire [47 : 0] P
);



wire [47:0] fft_sin_abs2;
assign  fft_sin_abs2 =  fft_sin_abs2_re2part+fft_sin_abs2_im2part;

reg m_fft_frame_check_data_tvalid_r;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        m_fft_frame_check_data_tvalid_r <=  0;
    else 
        m_fft_frame_check_data_tvalid_r <=m_fft_frame_check_data_tvalid;

end

(* mark_debug="true" *) reg [47:0] fft_sin_abs2_max;
 (* mark_debug="true" *)reg [15:0] cnt_fft_sin_abs2_max;

always@(posedge fifo7768_rdclk)begin        //获取sin fft的最大值 以及对应的点数
    if(!rstn)begin
        fft_sin_abs2_max    <=  0;
        cnt_fft_sin_abs2_max<=  0;
        end
    else if(state_r!=state)begin
        fft_sin_abs2_max    <=  0;
        cnt_fft_sin_abs2_max<=  0;
        end
    else if(state==FRAME_SINXOR)begin     
         if(m_fft_frame_check_data_tvalid_r &&  cnt_m_fft_frame_check_data<=1023)   
            if(fft_sin_abs2>=fft_sin_abs2_max)begin
                fft_sin_abs2_max    <=  fft_sin_abs2;
                cnt_fft_sin_abs2_max<=  cnt_m_fft_frame_check_data;
            end
    end
end


always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)begin
        frame_sin_ncfm  <=  0;
        frame_sin10khz_cfm   <=  0;
        sin_10khz_h <= 0;
    end
    
    else if(state==IDLE)begin
        frame_sin_ncfm  <=  0;
        frame_sin10khz_cfm   <=  0;        
        sin_10khz_h <=  0;
    end
    
    else if(state==DELAY1)begin
        if(cnt_rstn>=7)begin            
            frame_sin_ncfm <=  0;           
            end
    end
    
    else if(state==FRAME_SINXOR)begin
        if(cnt_m_fft_frame_check_data>=1023)begin
            if(389<= cnt_fft_sin_abs2_max&&cnt_fft_sin_abs2_max<= 430)begin // 位于9.5khz到10.5khz
                sin_10khz_h <=  1;
                if(fft_sin_abs2_max>=SIN_MAX ) // 大于sin 的触发阈值               
                    frame_sin10khz_cfm  <=  1;
                else 
                    frame_sin_ncfm      <=  1;
            end
            
            else 
                frame_sin_ncfm  <=  1;
        end
    end
    
    else begin
         frame_sin10khz_cfm  <=  frame_sin10khz_cfm;
         frame_sin_ncfm <=  frame_sin_ncfm;
    end
        
end


/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3   end ************/    
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3   end ************/  
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3   end ************/  
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3   end ************/  
   
   
  
   
/*************   进行细同步code1的检测  begin ************/    
/*************   进行细同步code1的检测  begin ************/  
/*************   进行细同步code1的检测  begin ************/  
/*************   进行细同步code1的检测  begin ************/ 




    
always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        frame_code_cut_valid <=  0;
    else if(state==FRAME_CODE1XOR)
        if(367<=cnt_m_fft_frame_check_data && cnt_m_fft_frame_check_data <= 622)
            frame_code_cut_valid <=  1;
    else
        frame_code_cut_valid <=  0;
    
end

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        frame_code_cut_valid_r <=  0;
  else
        frame_code_cut_valid_r <=  frame_code_cut_valid;
    
end

reg [15:0] ram_conjdata_addra_code1_num;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        ram_conjdata_addra_code1_num  <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_code1_num  <=  0;
    else if(frame_code_cut_valid)
        ram_conjdata_addra_code1_num  <=  ram_conjdata_addra_code1_num +1;
end

reg [15:0] ram_conjdata_addra_code1;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_code1 <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_code1 <=  0;
    else case(state)
        FRAME_CODE1XOR: ram_conjdata_addra_code1 <=  ram_conjdata_addra_code1_num;
        default:ram_conjdata_addra_code1 <=  0;
    endcase
      


end

wire [47:0] fftconj_300555_data;


blk_mem_gen_0 fram_code1_check (
  .clka(fifo7768_rdclk),    // input wire clka
  .ena(frame_code_cut_valid),      // input wire ena
  .addra(ram_conjdata_addra_code1),  // input wire [10 : 0] addra
  .douta(fftconj_300555_data)  // output wire [47 : 0] douta
);




reg s_mult_a_tvalid_code1check;

wire [79:0] m_mult_dout_tdata_code1check;
wire [32:0] m_mult_dout_tdata_code1check_re;
wire [32:0] m_mult_dout_tdata_code1check_im;

assign m_mult_dout_tdata_code1check_re = m_mult_dout_tdata_code1check[32:0];
assign m_mult_dout_tdata_code1check_im = m_mult_dout_tdata_code1check[72:40];

/* 调试信号 */
/* wire [23:0] fftconj_300555_data_re;
wire [23:0] fftconj_300555_data_im;
wire [23:0] fft_fifo_dout_re;
wire [23:0] fft_fifo_dout_im;


assign fftconj_300555_data_re=fftconj_300555_data[23:0];
assign fftconj_300555_data_im=fftconj_300555_data[47:24];
assign fft_fifo_dout_re =   fft_fifo_dout[23:0];
assign fft_fifo_dout_im =   fft_fifo_dout[47:24]; */

/*调试信号 end */

always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        s_mult_a_tvalid_code1check <=  0;
    else 
        s_mult_a_tvalid_code1check <=  frame_code_cut_valid;

end

wire m_mult_dout_tvalid_code1check;


conj_cmpy_mult conj_cmpy_mult_code1check (             
  .aclk(fifo7768_rdclk),                              // input wire aclk
  
  .s_axis_a_tvalid(s_mult_a_tvalid_code1check),        // input wire s_axis_a_tvalid
  .s_axis_a_tdata(m_fft_frame_check_data),          // input wire [47 : 0] s_axis_a_tdata
  
  .s_axis_b_tvalid(s_mult_a_tvalid_code1check),        // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fftconj_300555_data),          // input wire [47 : 0] s_axis_b_tdata
  
  .m_axis_dout_tvalid(m_mult_dout_tvalid_code1check),  // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_mult_dout_tdata_code1check)    // output wire [79 : 0] m_axis_dout_tdata
);                                         //乘法器 输出缩放65536倍



wire [79:0] s_ifft_data_tdata_code1check;
wire [79:0] m_ifft_Rxy_tdata_code1check;
wire m_ifft_Rxy_tvalid_code1check;
wire m_ifft_Rxy_tlast_code1check;
wire [48:0] m_ifft_Rxy_tdata_code1check_re;
wire [48:0] m_ifft_Rxy_tdata_code1check_im;

assign s_ifft_data_tdata_code1check = {{7'b0,m_mult_dout_tdata_code1check_im},{7'b0,m_mult_dout_tdata_code1check_re}};
assign m_ifft_Rxy_tdata_code1check_re = m_ifft_Rxy_tdata_code1check[32:0]<<16;
assign m_ifft_Rxy_tdata_code1check_im = m_ifft_Rxy_tdata_code1check[72:40]<<16; //左移16位 mult 因乘法器 缩放了65536

/*ifft 调试信号*/
/* wire [32:0] s_ifft_data_tdata_code1check_re;
wire [32:0] s_ifft_data_tdata_code1check_im;


assign s_ifft_data_tdata_code1check_re = s_ifft_data_tdata_code1check[32:0];
assign s_ifft_data_tdata_code1check_im = s_ifft_data_tdata_code1check[72:40];
 */
/*ifft 调试信号 end*/

// /*频谱截断后数据 共轭相乘完 进行 ifft （Rxy(n)）*/
xfft_0 xfft_0_Rxy_ifft_code1check (
  .aclk(fifo7768_rdclk),                                                 // input wire aclk
  
  .s_axis_config_tdata(16'b000_011010101010_0),    //最后一位0代表 做ifft 。 缩放256倍，实际无缩放 （ip核不做1/N 计算）   // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_ifft_data_tdata_code1check),                      // input wire [79 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(m_mult_dout_tvalid_code1check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxy_tdata_code1check),                      // output wire [79 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxy_tvalid_code1check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_ifft_Rxy_tlast_code1check),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);
/* Rxy[n]  ifft 幅值数据*/
reg m_ifft_Rxy_tvalid_code1check_r = 0;


wire [97:0] Rxy_abs2_code1check_re2part;
wire [97:0] Rxy_abs2_code1check_im2part;

mult_gen_0 Rxy_abs2_code1check_re2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_code1check_re),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_code1check_re),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_code1check),    // input wire CE
   
   .P(Rxy_abs2_code1check_re2part)      // output wire [97 : 0] P
);

mult_gen_0 Rxy_abs2_code1check_im2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_code1check_im),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_code1check_im),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_code1check),    // input wire CE
   
   .P(Rxy_abs2_code1check_im2part)      // output wire [97 : 0] P
);

reg [79:0] Rxy_abs2_code1check_multip;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        Rxy_abs2_code1check_multip <=  0;
    else if(state_r!=state)
        Rxy_abs2_code1check_multip    <=  0;        
    else if(state==FRAME_CODE1XOR)
        if(m_ifft_Rxy_tvalid_code1check)
            Rxy_abs2_code1check_multip <= Rxy_abs2_code1check_re2part+Rxy_abs2_code1check_im2part;

end


wire [63:0] Rxy_abs2_code1check_dimi65536;
assign Rxy_abs2_code1check_dimi65536 = Rxy_abs2_code1check_multip >>16;   //缩小65536倍 适配除法器输入位宽

reg fifo_Rxy_abs2_code1check_rden = 0;

wire [63:0] fifo_Rxy_abs2_code1check_sin_dout;

reg fifo_Rxy_abs2_code1check_sin_rst;  //状态变化时 fifo 复位(高电平有效)
always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        fifo_Rxy_abs2_code1check_sin_rst   <=  1;
    else if(state_r!=state)
        fifo_Rxy_abs2_code1check_sin_rst   <=  1;
    else
        fifo_Rxy_abs2_code1check_sin_rst   <=  0;

end

reg m_ifft_Rxy_tvalid_code1check_r2 = 0;
reg m_ifft_Rxy_tvalid_code1check_r3 = 0;


fifo_generator_2 fifo_Rxy_abs2_code1check_sin (  //将 Rxy_abs2_code1check 存到fifo中 等待输入到除法器
  .clk(fifo7768_rdclk),      // input wire clk
  .rst(fifo_Rxy_abs2_code1check_sin_rst),    // input wire srst
  
  .din(Rxy_abs2_code1check_dimi65536),      // input wire [63 : 0] din
  .wr_en(m_ifft_Rxy_tvalid_code1check_r2),  // input wire wr_en
  
  .rd_en(fifo_Rxy_abs2_code1check_rden),  // input wire rd_en
  .dout(fifo_Rxy_abs2_code1check_sin_dout),    // output wire [63 : 0] dout
  
  .full(),    // output wire full
  .empty()  // output wire empty
);

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_code1check 延时一拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_code1check_r <=  0;
    else if(state==FRAME_CODE1XOR)
        m_ifft_Rxy_tvalid_code1check_r <=  m_ifft_Rxy_tvalid_code1check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_code1check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_code1check_r2 <=  0;
    else if(state==FRAME_CODE1XOR)
        m_ifft_Rxy_tvalid_code1check_r2 <=  m_ifft_Rxy_tvalid_code1check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_code1check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_code1check_r3 <=  0;
    else if(state==FRAME_CODE1XOR)
        m_ifft_Rxy_tvalid_code1check_r3 <=  m_ifft_Rxy_tvalid_code1check_r2;
end

reg [79:0]  Rxy_abs2_code1check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_code1check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_code1check_n0 <=  0;
    else if(state==FRAME_CODE1XOR)
        if({m_ifft_Rxy_tvalid_code1check_r3,m_ifft_Rxy_tvalid_code1check_r2}==2'b01)  //检测到m_ifft_Rxy_tvalid_code1check 上升沿，保存Rxy_abs2_code1check 的第一个值 
            Rxy_abs2_code1check_n0 <=  Rxy_abs2_code1check_multip;
end

/* Rxy[n] ifft 幅值数据 end*/

/****   2          end             ****/  
 
 
/* **** 3 计算输入信号 ifft  sqrt_ifft abs ( fft_code1_cut )  **** */ 

wire [47:0] m_ifft_Rxx0_tdata_code1check;
wire m_ifft_Rxx0_tvalid_code1check;


// /*进行 Rxx(0) ifft 计算*/


xfft_2_Rxx0 xfft_2_Rxx0_code1check (
  .aclk(fifo7768_rdclk),    //  input wire aclk
  .s_axis_config_tdata(16'b000_011010101010_0),                  // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(m_fft_frame_check_data),                      // input wire [47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_mult_a_tvalid_code1check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxx0_tdata_code1check),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxx0_tvalid_code1check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);

/* Rxx0 ifft  sum 幅值数据*/

reg [47:0] fft_sin_cut_abs2_code1check_multip = 0;

wire [23:0] m_ifft_Rxx0_tdata_code1check_re;
wire [23:0] m_ifft_Rxx0_tdata_code1check_im;

assign m_ifft_Rxx0_tdata_code1check_re = m_ifft_Rxx0_tdata_code1check[23:0];
assign m_ifft_Rxx0_tdata_code1check_im = m_ifft_Rxx0_tdata_code1check[47:24];

wire [47:0] fft_sin_cut_abs2_code1check_repart;
wire [47:0] fft_sin_cut_abs2_code1check_impart;

mult_gen_sincut_abs2 fft_sin_cut_abs2_code1check_repartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_code1check_re),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_code1check_re),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_code1check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_code1check_repart)      // output wire [47 : 0] P
);

mult_gen_sincut_abs2 fft_sin_cut_abs2_code1check_impartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_code1check_im),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_code1check_im),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_code1check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_code1check_impart)      // output wire [47 : 0] P
);




always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fft_sin_cut_abs2_code1check_multip <=  0;
    else if(state==FRAME_CODE1XOR)
        if(m_ifft_Rxx0_tvalid_code1check)
            fft_sin_cut_abs2_code1check_multip <= fft_sin_cut_abs2_code1check_repart+fft_sin_cut_abs2_code1check_impart;
    else if(state_r != state)
        fft_sin_cut_abs2_code1check_multip    <=  0;
end


reg fft_sin_cut_sum_abs2_code1check_tvalid = 0;
reg fft_sin_cut_sum_abs2_code1check_tvalid_r=0;

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_code1check 延时一拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_code1check_tvalid <=  0;
    else 
        fft_sin_cut_sum_abs2_code1check_tvalid <= m_ifft_Rxx0_tvalid_code1check;

end

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_code1check 延时2拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_code1check_tvalid_r <=  0;
    else 
        fft_sin_cut_sum_abs2_code1check_tvalid_r <= fft_sin_cut_sum_abs2_code1check_tvalid;

end

reg [47:0]  fft_sin_cut_sum_abs2_code1check = 0;
always@(posedge fifo7768_rdclk)begin  //求 sum 即Rxx(0)^2值
    if(!rstn)
        fft_sin_cut_sum_abs2_code1check <=  0;
    else if(state==FRAME_CODE1XOR)
        if(fft_sin_cut_sum_abs2_code1check_tvalid_r)
            fft_sin_cut_sum_abs2_code1check <=  fft_sin_cut_sum_abs2_code1check + fft_sin_cut_abs2_code1check_multip;
    else if(state_r != state)
        fft_sin_cut_sum_abs2_code1check    <=  0;


end


/*  Rxx0 ifft  sum  幅值数据 end*/
/***** 3         end               ******/ 

/*          归一化互相关函数计算            */ 
reg  flag_Rxy_abs2_code1check_d = 0;
always@(posedge fifo7768_rdclk)begin   // Rxy_abs2_code1check 计算完成的标志信号
    if(!rstn)
        flag_Rxy_abs2_code1check_d <=  0;
    else if(state_r != state)
        flag_Rxy_abs2_code1check_d <=  0;
    else if(state==FRAME_CODE1XOR)
        if(m_ifft_Rxy_tlast_code1check)
            flag_Rxy_abs2_code1check_d <= 1;

end
 
reg flag_fft_sum_abs2_code1check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_code1check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_code1check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_code1check_d <=  0;
    else if(state==FRAME_CODE1XOR)
        if({fft_sin_cut_sum_abs2_code1check_tvalid_r,fft_sin_cut_sum_abs2_code1check_tvalid}==2'b10)
            flag_fft_sum_abs2_code1check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_code1check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_code1check  <=  0;
    else if(state_r!=state)
        cnt_fifo_Rxy_abs2_code1check   <=  0;
    else if(fifo_Rxy_abs2_code1check_rden)
        cnt_fifo_Rxy_abs2_code1check  <=  cnt_fifo_Rxy_abs2_code1check    +   1;

end 

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fifo_Rxy_abs2_code1check_rden  <=  0;
    else if(flag_fft_sum_abs2_code1check_d&&flag_Rxy_abs2_code1check_d)begin
            if(cnt_fifo_Rxy_abs2_code1check>=255)
                fifo_Rxy_abs2_code1check_rden  <=  0;
            else
                fifo_Rxy_abs2_code1check_rden  <=  1;     end 
    else 
        fifo_Rxy_abs2_code1check_rden  <=  0;
            
end



reg s_xcorr_dividend_tvalid_code1check = 0;
always@(posedge fifo7768_rdclk)begin     // 对fifo_Rxy_abs2_code1check_rden 延时一拍 作为除法器被除数有效信号
    if(!rstn)
        s_xcorr_dividend_tvalid_code1check  <=  0;
    else 
        s_xcorr_dividend_tvalid_code1check <=fifo_Rxy_abs2_code1check_rden;
    
end


reg [63:0] s_xcorr_divisor_tdata_code1check = 0;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        s_xcorr_divisor_tdata_code1check   <=  0;
    else if(state_r!=state)
        s_xcorr_divisor_tdata_code1check   <=  0;
    else case(state)
            FRAME_CODE1XOR: s_xcorr_divisor_tdata_code1check   <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_code1check;  
            default:s_xcorr_divisor_tdata_code1check   <=  0;
        endcase
        
end
    
wire m_xcorr_dout_tvalid_code1check;
wire [79:0]m_xcorr_sin_dout_tdata_code1check;
wire [63:0] code1check_quotient;
wire [10:0] code1check_fraction; 




div_gen_0 div_gen_0_xcorr_sin_code1check (
  .aclk(fifo7768_rdclk),                                      // input wire aclk
  
  .s_axis_divisor_tvalid(s_xcorr_dividend_tvalid_code1check),    // input wire s_axis_divisor_tvalid
//  .s_axis_divisor_tready(s_xcorr_sin_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(s_xcorr_divisor_tdata_code1check),      // input wire [63 : 0] s_axis_divisor_tdata 除数
  
  .s_axis_dividend_tvalid(s_xcorr_dividend_tvalid_code1check),  // input wire s_axis_dividend_tvalid
//  .s_axis_dividend_tready(s_xcorr_sin_dividend_tready),                            // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(fifo_Rxy_abs2_code1check_sin_dout),    // input wire [63 : 0] s_axis_dividend_tdata 被除数
  
  .m_axis_dout_tvalid(m_xcorr_dout_tvalid_code1check),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_xcorr_sin_dout_tdata_code1check)            // output wire [79 : 0] m_axis_dout_tdata
);

assign code1check_quotient = m_xcorr_sin_dout_tdata_code1check[74:11];
assign code1check_fraction = m_xcorr_sin_dout_tdata_code1check[10:0];

/*          归一化互相关函数计算  end          */  

/*     确认帧头flag信号    */

reg m_xcorr_dout_tvalid_code1check_r = 0;
always@(posedge fifo7768_rdclk or negedge rstn)begin //对m_xcorr_dout_tvalid_code1check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_code1check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_code1check_r    <=  m_xcorr_dout_tvalid_code1check;


end

(* mark_debug="true" *)reg [10:0] code1check_fraction_max;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        code1check_fraction_max <=  0;
    else if(state_r!=state)
        code1check_fraction_max <=  0;    
    else if(state==FRAME_CODE1XOR)begin
        if(m_xcorr_dout_tvalid_code1check && (code1check_fraction>code1check_fraction_max))
           code1check_fraction_max<=code1check_fraction;
    end

end


always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)begin
        frame_code1_ncfm  <=  0;
        frame_code1_cfm   <=  0;
        end
    else if(state==IDLE)begin
        frame_code1_ncfm  <=  0;
        frame_code1_cfm   <=  0;
    end
    
    else if(state==FRAME_CODE1CHECK1)begin
        if(rd_data_cnt>=2000)
            frame_code1_ncfm    <=  0;
    
    end
    
    else if(state==DELAY1)begin
        if(cnt_rstn>=7)begin            
            frame_code1_ncfm <=  0;           
            end
        end
        
    else if(state==FRAME_CODE1XOR)begin
        if({m_xcorr_dout_tvalid_code1check_r,m_xcorr_dout_tvalid_code1check}==2'b10)begin
            if(code1check_fraction_max>=CODE1_XCOR_MAX)
                frame_code1_cfm   <=  1;
            else
                frame_code1_ncfm  <=  1;
                end
        end        
    else begin
         frame_code1_cfm  <=  frame_code1_cfm;
         frame_code1_ncfm <=  frame_code1_ncfm;
         end
        
end


/*     确认帧头flag信号 end   */






/*************   进行细同步code1的检测    end ************/    
/*************   进行细同步code1的检测    end ************/  
/*************   进行细同步code1的检测    end ************/  
/*************   进行细同步code1的检测    end ************/ 

reg m_xcorr_dout_tvalid_pncode1check_r2;
reg m_xcorr_dout_tvalid_pncode1check_r;

always@(posedge fifo7768_rdclk)begin//复用次数 计数
    if(!rstn)
        f_cnt   <=  1;
    else if(state_r!=state)
        f_cnt   <=  1;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({m_xcorr_dout_tvalid_pncode1check_r2,m_xcorr_dout_tvalid_pncode1check_r}==2'b10)
            f_cnt   <=  f_cnt   +1;
end

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        f_cnt_r   <=  0;
    else 
        f_cnt_r     <=  f_cnt;
end


reg rom_m_fft_frame_check_data_cut_ena;
reg rom_m_fft_frame_check_data_cut_wea;
reg [7:0] rom_m_fft_frame_check_data_cut_addr;
wire [47:0] rom_m_fft_frame_check_data_cut_dout;

m_fft_frame_check_data_cut m_fft_frame_check_data_cut (
  .clka(fifo7768_rdclk),    // input wire clka
  .ena(rom_m_fft_frame_check_data_cut_ena),      // input wire ena
  .wea(rom_m_fft_frame_check_data_cut_wea),      // input wire [0 : 0] wea
  .addra(rom_m_fft_frame_check_data_cut_addr),  // input wire [7 : 0] addra
  .dina(m_fft_frame_check_data),    // input wire [47 : 0] dina
  .douta(rom_m_fft_frame_check_data_cut_dout)  // output wire [47 : 0] douta
);

reg frame_pncode2_cut_valid;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)begin
        rom_m_fft_frame_check_data_cut_ena   <=  0;
        rom_m_fft_frame_check_data_cut_wea  <=  0;
    end
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(f_cnt==1)begin
            rom_m_fft_frame_check_data_cut_ena  <=  frame_pncode2_cut_valid;
            rom_m_fft_frame_check_data_cut_wea  <=  frame_pncode2_cut_valid;
        end
        else begin
            if(rom_m_fft_frame_check_data_cut_addr<=254)begin
                rom_m_fft_frame_check_data_cut_ena  <=  1;
                rom_m_fft_frame_check_data_cut_wea  <=  0;    
            end
            else begin
                rom_m_fft_frame_check_data_cut_ena  <=  0;
                rom_m_fft_frame_check_data_cut_wea  <=  0;              
            
            end
            
        end
   else begin
        rom_m_fft_frame_check_data_cut_ena   <=  0;
        rom_m_fft_frame_check_data_cut_wea  <=  0;
   
   end
    
end



always@(posedge fifo7768_rdclk)begin
    if(!rstn)begin
        rom_m_fft_frame_check_data_cut_addr <=  0;
    end
    
    else if(f_cnt_r!=f_cnt)
        rom_m_fft_frame_check_data_cut_addr <=  0;
        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))begin
        if((rom_m_fft_frame_check_data_cut_ena)&&(rom_m_fft_frame_check_data_cut_addr==255))
            rom_m_fft_frame_check_data_cut_addr <=  rom_m_fft_frame_check_data_cut_addr;
        else if(rom_m_fft_frame_check_data_cut_ena)   
            rom_m_fft_frame_check_data_cut_addr <=  rom_m_fft_frame_check_data_cut_addr+1;
        

   end
    
end

reg [47:0] s_fft_frame_check_data_mult;

always@(*)begin
    if(!rstn)
        s_fft_frame_check_data_mult <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        case(f_cnt)
            1:s_fft_frame_check_data_mult <=  m_fft_frame_check_data;
            2:s_fft_frame_check_data_mult <=  rom_m_fft_frame_check_data_cut_dout;
            default:s_fft_frame_check_data_mult <=  rom_m_fft_frame_check_data_cut_dout;
        endcase
end




/*************    pncode1.5.9.13_check    begin    ************/    
/*************    pncode1_check    begin    ************/  
/*************    pncode1_check    begin    ************/  
/*************    pncode1_check    begin    ************/ 






    
always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        frame_pncode2_cut_valid <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))begin
        if(f_cnt==1)begin       
            if(367<=cnt_m_fft_frame_check_data && cnt_m_fft_frame_check_data <= 622)
                frame_pncode2_cut_valid <=  1;
            else
                 frame_pncode2_cut_valid <=  0;
        end
        else if(f_cnt!=1)begin
            if(rom_m_fft_frame_check_data_cut_addr<=254)
                frame_pncode2_cut_valid <=  1;
            else
                frame_pncode2_cut_valid <=  0;
        end
    end
    else
        frame_pncode2_cut_valid <=  0;
    
end

reg [15:0] ram_conjdata_addra;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        ram_conjdata_addra  <=  0;
    else if(state_r!=state)
        ram_conjdata_addra  <=  0;
    else if(f_cnt_r!=f_cnt)
        ram_conjdata_addra  <=  0;
    else if(frame_pncode2_cut_valid)
        ram_conjdata_addra  <=  ram_conjdata_addra +1;
end



reg [15:0] ram_conjdata_addra_pncode1check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode1check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode1check <=  0;
    else if(f_cnt_r!=f_cnt)
        ram_conjdata_addra_pncode1check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode1check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra;
                2:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+1024 ;
                3:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+2048 ;
                4:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+3072 ;
                5:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+4096 ;
                6:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+5120 ;
                7:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+6144 ;
                8:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+7168 ;
                9:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+8192 ;
                10:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+9216 ;
                11:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+10240;
                12:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+11264;
                13:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+12288;
                14:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+13312;
                15:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+14336;
                16:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+15360;
                17:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+16384;
                18:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+17408;
                19:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+18432;
                20:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+19456;
                21:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+20480;
                22:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+21504;
                23:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+22528;
                24:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+23552;
                25:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+24576;
                26:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+25600;
                27:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+26624;
                28:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+27648;
                29:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+28672;
                30:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+29696;
                31:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+30720;
                32:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+31744;
                33:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+32768;
                34:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+33792;
                35:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+34816;
                36:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+35840;
                37:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+36864;
                38:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+37888;
                39:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+38912;
                40:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+39936;
                41:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+40960;
                42:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+41984;
                43:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+43008;
                44:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+44032;
                45:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+45056;
                46:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+46080;
                47:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+47104;
                48:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+48128;
                49:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+49152;
                50:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+50176;
                51:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+51200;
                52:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+52224;
                53:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+53248;
                54:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+54272;
                55:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+55296;
                56:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+56320;
                57:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+57344;
                58:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+58368;
                59:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+59392;
                60:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+60416;
                61:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+61440;
                62:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+62464;
                63:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+63488;
                64:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+64512;
                                                                                  
            endcase
            end
        FRAME_P3XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra;
                2:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+1024 ;
                3:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+2048 ;
                4:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+3072 ;
                5:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+4096 ;
                6:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+5120 ;
                7:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+6144 ;
                8:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+7168 ;
                9:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+8192 ;
                10:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+9216 ;
                11:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+10240;
                12:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+11264;
                13:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+12288;
                14:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+13312;
                15:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+14336;
                16:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+15360;
                17:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+16384;
                18:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+17408;
                19:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+18432;
                20:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+19456;
                21:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+20480;
                22:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+21504;
                23:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+22528;
                24:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+23552;
                25:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+24576;
                26:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+25600;
                27:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+26624;
                28:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+27648;
                29:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+28672;
                30:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+29696;
                31:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+30720;
                32:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+31744;
                33:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+32768;
                34:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+33792;
                35:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+34816;
                36:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+35840;
                37:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+36864;
                38:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+37888;
                39:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+38912;
                40:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+39936;
                41:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+40960;
                42:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+41984;
                43:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+43008;
                44:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+44032;
                45:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+45056;
                46:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+46080;
                47:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+47104;
                48:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+48128;
                49:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+49152;
                50:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+50176;
                51:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+51200;
                52:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+52224;
                53:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+53248;
                54:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+54272;
                55:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+55296;
                56:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+56320;
                57:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+57344;
                58:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+58368;
                59:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+59392;
                60:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+60416;
                61:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+61440;
                62:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+62464;
                63:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+63488;
                64:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+64512;
            endcase
            end
        FRAME_P4XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra;
                2:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+1024 ;
                3:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+2048 ;
                4:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+3072 ;
                5:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+4096 ;
                6:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+5120 ;
                7:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+6144 ;
                8:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+7168 ;
                9:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+8192 ;
                10:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+9216 ;
                11:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+10240;
                12:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+11264;
                13:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+12288;
                14:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+13312;
                15:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+14336;
                16:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+15360;
                17:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+16384;
                18:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+17408;
                19:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+18432;
                20:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+19456;
                21:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+20480;
                22:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+21504;
                23:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+22528;
                24:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+23552;
                25:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+24576;
                26:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+25600;
                27:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+26624;
                28:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+27648;
                29:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+28672;
                30:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+29696;
                31:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+30720;
                32:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+31744;
                33:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+32768;
                34:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+33792;
                35:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+34816;
                36:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+35840;
                37:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+36864;
                38:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+37888;
                39:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+38912;
                40:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+39936;
                41:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+40960;
                42:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+41984;
                43:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+43008;
                44:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+44032;
                45:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+45056;
                46:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+46080;
                47:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+47104;
                48:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+48128;
                49:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+49152;
                50:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+50176;
                51:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+51200;
                52:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+52224;
                53:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+53248;
                54:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+54272;
                55:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+55296;
                56:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+56320;
                57:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+57344;
                58:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+58368;
                59:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+59392;
                60:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+60416;
                61:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+61440;
                62:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+62464;
                63:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+63488;
                64:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+64512;
            endcase
            end
        FRAME_P5XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra;
                2:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+1024 ;
                3:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+2048 ;
                4:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+3072 ;
                5:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+4096 ;
                6:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+5120 ;
                7:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+6144 ;
                8:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+7168 ;
                9:      ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+8192 ;
                10:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+9216 ;
                11:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+10240;
                12:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+11264;
                13:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+12288;
                14:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+13312;
                15:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+14336;
                16:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+15360;
                17:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+16384;
                18:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+17408;
                19:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+18432;
                20:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+19456;
                21:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+20480;
                22:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+21504;
                23:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+22528;
                24:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+23552;
                25:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+24576;
                26:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+25600;
                27:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+26624;
                28:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+27648;
                29:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+28672;
                30:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+29696;
                31:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+30720;
                32:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+31744;
                33:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+32768;
                34:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+33792;
                35:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+34816;
                36:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+35840;
                37:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+36864;
                38:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+37888;
                39:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+38912;
                40:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+39936;
                41:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+40960;
                42:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+41984;
                43:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+43008;
                44:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+44032;
                45:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+45056;
                46:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+46080;
                47:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+47104;
                48:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+48128;
                49:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+49152;
                50:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+50176;
                51:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+51200;
                52:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+52224;
                53:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+53248;
                54:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+54272;
                55:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+55296;
                56:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+56320;
                57:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+57344;
                58:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+58368;
                59:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+59392;
                60:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+60416;
                61:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+61440;
                62:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+62464;
                63:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+63488;
                64:     ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+64512;
            endcase
            end
        default:ram_conjdata_addra_pncode1check <=  0;
    endcase
      


end

wire [47:0] fftconj_300555_data_pncode1check;


blk_mem_gen_0 fram_pncode1check (
  .clka(fifo7768_rdclk),    // input wire clka
  .ena(frame_pncode2_cut_valid),      // input wire ena
  .addra(ram_conjdata_addra_pncode1check),  // input wire [10 : 0] addra
  .douta(fftconj_300555_data_pncode1check)  // output wire [47 : 0] douta
);




reg s_mult_a_tvalid_pncode1check;

wire [79:0] m_mult_dout_tdata_pncode1check;
wire [32:0] m_mult_dout_tdata_pncode1check_re;
wire [32:0] m_mult_dout_tdata_pncode1check_im;

assign m_mult_dout_tdata_pncode1check_re = m_mult_dout_tdata_pncode1check[32:0];
assign m_mult_dout_tdata_pncode1check_im = m_mult_dout_tdata_pncode1check[72:40];

/* 调试信号 */
/* wire [23:0] fftconj_300555_data_pncode1check_re;
wire [23:0] fftconj_300555_data_pncode1check_im;
wire [23:0] fft_fifo_dout_re;
wire [23:0] fft_fifo_dout_im;


assign fftconj_300555_data_pncode1check_re=fftconj_300555_data_pncode1check[23:0];
assign fftconj_300555_data_pncode1check_im=fftconj_300555_data_pncode1check[47:24];
assign fft_fifo_dout_re =   fft_fifo_dout[23:0];
assign fft_fifo_dout_im =   fft_fifo_dout[47:24]; */

/*调试信号 end */

always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        s_mult_a_tvalid_pncode1check <=  0;
    else 
        s_mult_a_tvalid_pncode1check <=  frame_pncode2_cut_valid;

end

wire m_mult_dout_tvalid_pncode1check;



conj_cmpy_mult conj_cmpy_mult_pncode1check (             
  .aclk(fifo7768_rdclk),                              // input wire aclk
  
  .s_axis_a_tvalid(s_mult_a_tvalid_pncode1check),        // input wire s_axis_a_tvalid
  .s_axis_a_tdata(s_fft_frame_check_data_mult),          // input wire [47 : 0] s_axis_a_tdata
  
  .s_axis_b_tvalid(s_mult_a_tvalid_pncode1check),        // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fftconj_300555_data_pncode1check),          // input wire [47 : 0] s_axis_b_tdata
  
  .m_axis_dout_tvalid(m_mult_dout_tvalid_pncode1check),  // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_mult_dout_tdata_pncode1check)    // output wire [79 : 0] m_axis_dout_tdata
);                                         //乘法器 输出缩放65536倍



wire [79:0] s_ifft_data_tdata_pncode1check;
wire [79:0] m_ifft_Rxy_tdata_pncode1check;
wire m_ifft_Rxy_tvalid_pncode1check;
wire m_ifft_Rxy_tlast_pncode1check;
wire [48:0] m_ifft_Rxy_tdata_pncode1check_re;
wire [48:0] m_ifft_Rxy_tdata_pncode1check_im;

assign s_ifft_data_tdata_pncode1check = {{7'b0,m_mult_dout_tdata_pncode1check_im},{7'b0,m_mult_dout_tdata_pncode1check_re}};
assign m_ifft_Rxy_tdata_pncode1check_re = m_ifft_Rxy_tdata_pncode1check[32:0]<<16;
assign m_ifft_Rxy_tdata_pncode1check_im = m_ifft_Rxy_tdata_pncode1check[72:40]<<16; //左移16位 mult 因乘法器 缩放了65536

/*ifft 调试信号*/
/* wire [32:0] s_ifft_data_tdata_pncode1check_re;
wire [32:0] s_ifft_data_tdata_pncode1check_im;


assign s_ifft_data_tdata_pncode1check_re = s_ifft_data_tdata_pncode1check[32:0];
assign s_ifft_data_tdata_pncode1check_im = s_ifft_data_tdata_pncode1check[72:40];
 */
/*ifft 调试信号 end*/

// /*频谱截断后数据 共轭相乘完 进行 ifft （Rxy(n)）*/
xfft_0 xfft_0_Rxy_ifft_pncode1check (
  .aclk(fifo7768_rdclk),                                                 // input wire aclk
  
  .s_axis_config_tdata(16'b000_011010101010_0),    //最后一位0代表 做ifft 。 缩放256倍，实际无缩放 （ip核不做1/N 计算）   // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_ifft_data_tdata_pncode1check),                      // input wire [79 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(m_mult_dout_tvalid_pncode1check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxy_tdata_pncode1check),                      // output wire [79 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxy_tvalid_pncode1check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_ifft_Rxy_tlast_pncode1check),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);
/* Rxy[n]  ifft 幅值数据*/
reg m_ifft_Rxy_tvalid_pncode1check_r = 0;


wire [97:0] Rxy_abs2_pncode1check_re2part;
wire [97:0] Rxy_abs2_pncode1check_im2part;

mult_gen_0 Rxy_abs2_pncode1check_re2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode1check_re),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode1check_re),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode1check),    // input wire CE
   
   .P(Rxy_abs2_pncode1check_re2part)      // output wire [97 : 0] P
);

mult_gen_0 Rxy_abs2_pncode1check_im2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode1check_im),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode1check_im),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode1check),    // input wire CE
   
   .P(Rxy_abs2_pncode1check_im2part)      // output wire [97 : 0] P
);

reg [79:0] Rxy_abs2_pncode1check_multip;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        Rxy_abs2_pncode1check_multip <=  0;
    else if(state_r!=state)
        Rxy_abs2_pncode1check_multip    <=  0;
    else if(f_cnt_r!=f_cnt)
        Rxy_abs2_pncode1check_multip    <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR||(state==FRAME_P5XOR)))
        if(m_ifft_Rxy_tvalid_pncode1check)
            Rxy_abs2_pncode1check_multip <= Rxy_abs2_pncode1check_re2part+Rxy_abs2_pncode1check_im2part;

end


wire [63:0] Rxy_abs2_pncode1check_dimi65536;
assign Rxy_abs2_pncode1check_dimi65536 = Rxy_abs2_pncode1check_multip >>16;   //缩小65536倍 适配除法器输入位宽

reg fifo_Rxy_abs2_pncode1check_rden = 0;

wire [63:0] fifo_Rxy_abs2_pncode1check_sin_dout;

reg fifo_Rxy_abs2_pncode1check_sin_rst;  //状态变化时 fifo 复位(高电平有效)
always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode1check_sin_rst   <=  1;
    else if(state_r!=state)
        fifo_Rxy_abs2_pncode1check_sin_rst   <=  1;
    else if(f_cnt_r!=f_cnt)
        fifo_Rxy_abs2_pncode1check_sin_rst   <=  1;        
    else
        fifo_Rxy_abs2_pncode1check_sin_rst   <=  0;

end

reg m_ifft_Rxy_tvalid_pncode1check_r2 = 0;
reg m_ifft_Rxy_tvalid_pncode1check_r3 = 0;


fifo_generator_2 fifo_Rxy_abs2_pncode1check_sin (  //将 Rxy_abs2_pncode1check 存到fifo中 等待输入到除法器
  .clk(fifo7768_rdclk),      // input wire clk
  .rst(fifo_Rxy_abs2_pncode1check_sin_rst),    // input wire srst
  
  .din(Rxy_abs2_pncode1check_dimi65536),      // input wire [63 : 0] din
  .wr_en(m_ifft_Rxy_tvalid_pncode1check_r2),  // input wire wr_en
  
  .rd_en(fifo_Rxy_abs2_pncode1check_rden),  // input wire rd_en
  .dout(fifo_Rxy_abs2_pncode1check_sin_dout),    // output wire [63 : 0] dout
  
  .full(),    // output wire full
  .empty()  // output wire empty
);

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode1check 延时一拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode1check_r <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode1check_r <=  m_ifft_Rxy_tvalid_pncode1check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode1check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode1check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode1check_r2 <=  m_ifft_Rxy_tvalid_pncode1check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode1check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode1check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode1check_r3 <=  m_ifft_Rxy_tvalid_pncode1check_r2;
end

reg [79:0]  Rxy_abs2_pncode1check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode1check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode1check_n0 <=  0;
    else if(f_cnt_r != f_cnt)
        Rxy_abs2_pncode1check_n0 <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({m_ifft_Rxy_tvalid_pncode1check_r3,m_ifft_Rxy_tvalid_pncode1check_r2}==2'b01)  //检测到m_ifft_Rxy_tvalid_pncode1check 上升沿，保存Rxy_abs2_pncode1check 的第一个值 
            Rxy_abs2_pncode1check_n0 <=  Rxy_abs2_pncode1check_multip;
end

/* Rxy[n] ifft 幅值数据 end*/

/****   2          end             ****/  
 
 
/* **** 3 计算输入信号 ifft  sqrt_ifft abs ( fft_code1_cut )  **** */ 

wire [47:0] m_ifft_Rxx0_tdata_pncode1check;
wire m_ifft_Rxx0_tvalid_pncode1check;


// /*进行 Rxx(0) ifft 计算*/


xfft_2_Rxx0 xfft_2_Rxx0_pncode1check (
  .aclk(fifo7768_rdclk),    //  input wire aclk
  .s_axis_config_tdata(16'b000_011010101010_0),                  // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_fft_frame_check_data_mult),                      // input wire [47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_mult_a_tvalid_pncode1check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxx0_tdata_pncode1check),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxx0_tvalid_pncode1check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);

/* Rxx0 ifft  sum 幅值数据*/

reg [47:0] fft_sin_cut_abs2_pncode1check_multip = 0;

wire [23:0] m_ifft_Rxx0_tdata_pncode1check_re;
wire [23:0] m_ifft_Rxx0_tdata_pncode1check_im;

assign m_ifft_Rxx0_tdata_pncode1check_re = m_ifft_Rxx0_tdata_pncode1check[23:0];
assign m_ifft_Rxx0_tdata_pncode1check_im = m_ifft_Rxx0_tdata_pncode1check[47:24];

wire [47:0] fft_sin_cut_abs2_pncode1check_repart;
wire [47:0] fft_sin_cut_abs2_pncode1check_impart;

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode1check_repartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode1check_re),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode1check_re),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode1check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode1check_repart)      // output wire [47 : 0] P
);

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode1check_impartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode1check_im),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode1check_im),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode1check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode1check_impart)      // output wire [47 : 0] P
);




always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fft_sin_cut_abs2_pncode1check_multip <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxx0_tvalid_pncode1check)
            fft_sin_cut_abs2_pncode1check_multip <= fft_sin_cut_abs2_pncode1check_repart+fft_sin_cut_abs2_pncode1check_impart;
    else if(state_r != state)
        fft_sin_cut_abs2_pncode1check_multip    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_abs2_pncode1check_multip    <=  0;
end


reg fft_sin_cut_sum_abs2_pncode1check_tvalid = 0;
reg fft_sin_cut_sum_abs2_pncode1check_tvalid_r=0;

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode1check 延时一拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode1check_tvalid <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode1check_tvalid <= m_ifft_Rxx0_tvalid_pncode1check;

end

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode1check 延时2拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode1check_tvalid_r <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode1check_tvalid_r <= fft_sin_cut_sum_abs2_pncode1check_tvalid;

end

reg [47:0]  fft_sin_cut_sum_abs2_pncode1check = 0;
always@(posedge fifo7768_rdclk)begin  //求 sum 即Rxx(0)^2值
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode1check <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(fft_sin_cut_sum_abs2_pncode1check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode1check <=  fft_sin_cut_sum_abs2_pncode1check + fft_sin_cut_abs2_pncode1check_multip;
    else if(state_r != state)
        fft_sin_cut_sum_abs2_pncode1check    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_sum_abs2_pncode1check    <=  0;

end


/*  Rxx0 ifft  sum  幅值数据 end*/
/***** 3         end               ******/ 

/*          归一化互相关函数计算            */ 
reg  flag_Rxy_abs2_pncode1check_d = 0;
always@(posedge fifo7768_rdclk)begin   // Rxy_abs2_pncode1check 计算完成的标志信号
    if(!rstn)
        flag_Rxy_abs2_pncode1check_d <=  0;
    else if(state_r != state)
        flag_Rxy_abs2_pncode1check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_Rxy_abs2_pncode1check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxy_tlast_pncode1check)
            flag_Rxy_abs2_pncode1check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode1check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode1check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode1check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode1check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_fft_sum_abs2_pncode1check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({fft_sin_cut_sum_abs2_pncode1check_tvalid_r,fft_sin_cut_sum_abs2_pncode1check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode1check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode1check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode1check  <=  0;
    else if(state_r!=state)
        cnt_fifo_Rxy_abs2_pncode1check   <=  0;
    else if(f_cnt_r!=f_cnt)
        cnt_fifo_Rxy_abs2_pncode1check   <=  0;        
        
    else if(fifo_Rxy_abs2_pncode1check_rden)
        cnt_fifo_Rxy_abs2_pncode1check  <=  cnt_fifo_Rxy_abs2_pncode1check    +   1;

end 

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode1check_rden  <=  0;
    else if(flag_fft_sum_abs2_pncode1check_d&&flag_Rxy_abs2_pncode1check_d)begin
            if(cnt_fifo_Rxy_abs2_pncode1check>=255)
                fifo_Rxy_abs2_pncode1check_rden  <=  0;
            else
                fifo_Rxy_abs2_pncode1check_rden  <=  1;     end 
    else 
        fifo_Rxy_abs2_pncode1check_rden  <=  0;
            
end



reg s_xcorr_dividend_tvalid_pncode1check = 0;
always@(posedge fifo7768_rdclk)begin     // 对fifo_Rxy_abs2_pncode1check_rden 延时一拍 作为除法器被除数有效信号
    if(!rstn)
        s_xcorr_dividend_tvalid_pncode1check  <=  0;
    else 
        s_xcorr_dividend_tvalid_pncode1check <=fifo_Rxy_abs2_pncode1check_rden;
    
end


reg [63:0] s_xcorr_divisor_tdata_pncode1check = 0;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        s_xcorr_divisor_tdata_pncode1check   <=  0;
    else if(state_r!=state)
        s_xcorr_divisor_tdata_pncode1check   <=  0;
    else case(state)  
            FRAME_P2XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    2:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R550_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    3:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R990_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    4:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R13130_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    default:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                endcase
            end
            FRAME_P3XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    2:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R550_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    3:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R990_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    4:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R13130_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    default:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                endcase
            end
            FRAME_P4XOR: begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    2:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R550_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    3:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R990_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    4:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R13130_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    default:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                endcase
            end
            FRAME_P5XOR:  begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    2:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R550_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    3:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R990_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    4:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R13130_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                    default:s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
                endcase
            end
            default:s_xcorr_divisor_tdata_pncode1check   <=  0;
        endcase
        
end
    
wire m_xcorr_dout_tvalid_pncode1check;
wire [79:0]m_xcorr_sin_dout_tdata_pncode1check;
wire [63:0] pncode1check_quotient;
wire [10:0] pncode1check_fraction; 




div_gen_0 div_gen_0_xcorr_sin_pncode1check (
  .aclk(fifo7768_rdclk),                                      // input wire aclk
  
  .s_axis_divisor_tvalid(s_xcorr_dividend_tvalid_pncode1check),    // input wire s_axis_divisor_tvalid
//  .s_axis_divisor_tready(s_xcorr_sin_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(s_xcorr_divisor_tdata_pncode1check),      // input wire [63 : 0] s_axis_divisor_tdata 除数
  
  .s_axis_dividend_tvalid(s_xcorr_dividend_tvalid_pncode1check),  // input wire s_axis_dividend_tvalid
//  .s_axis_dividend_tready(s_xcorr_sin_dividend_tready),                            // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(fifo_Rxy_abs2_pncode1check_sin_dout),    // input wire [63 : 0] s_axis_dividend_tdata 被除数
  
  .m_axis_dout_tvalid(m_xcorr_dout_tvalid_pncode1check),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_xcorr_sin_dout_tdata_pncode1check)            // output wire [79 : 0] m_axis_dout_tdata
);

assign pncode1check_quotient = m_xcorr_sin_dout_tdata_pncode1check[74:11];
assign pncode1check_fraction = m_xcorr_sin_dout_tdata_pncode1check[10:0];

/*          归一化互相关函数计算  end          */  

/*     确认帧头flag信号    */


always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode1check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode1check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode1check_r    <=  m_xcorr_dout_tvalid_pncode1check;


end


always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode1check 延时2拍
    if(!rstn)
        m_xcorr_dout_tvalid_pncode1check_r2   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode1check_r2    <=  m_xcorr_dout_tvalid_pncode1check_r;


end


(* mark_debug="true" *)reg [10:0] pncode1check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode1check_fraction_max <=  0;
    else if(state_r!=state)
        pncode1check_fraction_max <=  0;
    else if(f_cnt_r!=f_cnt)
        pncode1check_fraction_max <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))begin
        if(m_xcorr_dout_tvalid_pncode1check && (pncode1check_fraction>pncode1check_fraction_max))
           pncode1check_fraction_max<=pncode1check_fraction;
    end

end


/*************    pncode1_check    end    ************/    
/*************    pncode1_check    end    ************/  
/*************    pncode1_check    end    ************/  
/*************    pncode1_check    end    ************/ 






/*************    pncode2_check    begin    ************/    
/*************    pncode2_check    begin    ************/  
/*************    pncode2_check    begin    ************/  
/*************    pncode2_check    begin    ************/ 





reg [15:0] ram_conjdata_addra_pncode2check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode2check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode2check <=  0;
    else if(f_cnt_r!=f_cnt)
        ram_conjdata_addra_pncode2check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode2check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256       ;
                2:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+1024 ;
                3:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+2048 ;
                4:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+3072 ;
                5:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+4096 ;
                6:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+5120 ;
                7:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+6144 ;
                8:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+7168 ;
                9:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+8192 ;
                10:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+9216 ;
                11:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+10240;
                12:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+11264;
                13:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+12288;
                14:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+13312;
                15:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+14336;
                16:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+15360;
                17:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+16384;
                18:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+17408;
                19:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+18432;
                20:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+19456;
                21:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+20480;
                22:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+21504;
                23:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+22528;
                24:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+23552;
                25:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+24576;
                26:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+25600;
                27:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+26624;
                28:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+27648;
                29:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+28672;
                30:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+29696;
                31:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+30720;
                32:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+31744;
                33:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+32768;
                34:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+33792;
                35:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+34816;
                36:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+35840;
                37:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+36864;
                38:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+37888;
                39:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+38912;
                40:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+39936;
                41:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+40960;
                42:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+41984;
                43:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+43008;
                44:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+44032;
                45:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+45056;
                46:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+46080;
                47:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+47104;
                48:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+48128;
                49:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+49152;
                50:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+50176;
                51:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+51200;
                52:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+52224;
                53:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+53248;
                54:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+54272;
                55:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+55296;
                56:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+56320;
                57:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+57344;
                58:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+58368;
                59:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+59392;
                60:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+60416;
                61:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+61440;
                62:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+62464;
                63:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+63488;
                64:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+64512;
            endcase
            end
        FRAME_P3XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256       ;
                2:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+1024 ;
                3:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+2048 ;
                4:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+3072 ;
                5:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+4096 ;
                6:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+5120 ;
                7:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+6144 ;
                8:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+7168 ;
                9:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+8192 ;
                10:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+9216 ;
                11:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+10240;
                12:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+11264;
                13:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+12288;
                14:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+13312;
                15:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+14336;
                16:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+15360;
                17:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+16384;
                18:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+17408;
                19:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+18432;
                20:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+19456;
                21:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+20480;
                22:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+21504;
                23:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+22528;
                24:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+23552;
                25:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+24576;
                26:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+25600;
                27:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+26624;
                28:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+27648;
                29:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+28672;
                30:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+29696;
                31:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+30720;
                32:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+31744;
                33:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+32768;
                34:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+33792;
                35:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+34816;
                36:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+35840;
                37:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+36864;
                38:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+37888;
                39:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+38912;
                40:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+39936;
                41:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+40960;
                42:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+41984;
                43:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+43008;
                44:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+44032;
                45:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+45056;
                46:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+46080;
                47:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+47104;
                48:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+48128;
                49:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+49152;
                50:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+50176;
                51:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+51200;
                52:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+52224;
                53:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+53248;
                54:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+54272;
                55:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+55296;
                56:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+56320;
                57:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+57344;
                58:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+58368;
                59:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+59392;
                60:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+60416;
                61:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+61440;
                62:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+62464;
                63:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+63488;
                64:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+64512;
            endcase
            end
        FRAME_P4XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256       ;
                2:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+1024 ;
                3:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+2048 ;
                4:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+3072 ;
                5:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+4096 ;
                6:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+5120 ;
                7:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+6144 ;
                8:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+7168 ;
                9:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+8192 ;
                10:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+9216 ;
                11:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+10240;
                12:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+11264;
                13:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+12288;
                14:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+13312;
                15:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+14336;
                16:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+15360;
                17:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+16384;
                18:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+17408;
                19:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+18432;
                20:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+19456;
                21:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+20480;
                22:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+21504;
                23:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+22528;
                24:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+23552;
                25:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+24576;
                26:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+25600;
                27:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+26624;
                28:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+27648;
                29:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+28672;
                30:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+29696;
                31:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+30720;
                32:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+31744;
                33:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+32768;
                34:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+33792;
                35:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+34816;
                36:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+35840;
                37:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+36864;
                38:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+37888;
                39:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+38912;
                40:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+39936;
                41:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+40960;
                42:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+41984;
                43:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+43008;
                44:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+44032;
                45:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+45056;
                46:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+46080;
                47:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+47104;
                48:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+48128;
                49:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+49152;
                50:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+50176;
                51:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+51200;
                52:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+52224;
                53:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+53248;
                54:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+54272;
                55:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+55296;
                56:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+56320;
                57:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+57344;
                58:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+58368;
                59:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+59392;
                60:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+60416;
                61:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+61440;
                62:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+62464;
                63:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+63488;
                64:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+64512;
            endcase
            end
        FRAME_P5XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256       ;
                2:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+1024 ;
                3:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+2048 ;
                4:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+3072 ;
                5:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+4096 ;
                6:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+5120 ;
                7:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+6144 ;
                8:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+7168 ;
                9:      ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+8192 ;
                10:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+9216 ;
                11:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+10240;
                12:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+11264;
                13:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+12288;
                14:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+13312;
                15:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+14336;
                16:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+15360;
                17:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+16384;
                18:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+17408;
                19:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+18432;
                20:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+19456;
                21:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+20480;
                22:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+21504;
                23:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+22528;
                24:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+23552;
                25:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+24576;
                26:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+25600;
                27:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+26624;
                28:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+27648;
                29:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+28672;
                30:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+29696;
                31:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+30720;
                32:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+31744;
                33:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+32768;
                34:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+33792;
                35:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+34816;
                36:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+35840;
                37:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+36864;
                38:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+37888;
                39:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+38912;
                40:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+39936;
                41:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+40960;
                42:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+41984;
                43:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+43008;
                44:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+44032;
                45:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+45056;
                46:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+46080;
                47:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+47104;
                48:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+48128;
                49:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+49152;
                50:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+50176;
                51:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+51200;
                52:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+52224;
                53:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+53248;
                54:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+54272;
                55:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+55296;
                56:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+56320;
                57:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+57344;
                58:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+58368;
                59:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+59392;
                60:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+60416;
                61:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+61440;
                62:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+62464;
                63:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+63488;
                64:     ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+256+64512;
            endcase
            end
        default:ram_conjdata_addra_pncode2check <=  0;
    endcase
      


end

wire [47:0] fftconj_300555_data_pncode2check;


blk_mem_gen_0 fram_pncode2check (
  .clka(fifo7768_rdclk),    // input wire clka
  .ena(frame_pncode2_cut_valid),      // input wire ena
  .addra(ram_conjdata_addra_pncode2check),  // input wire [10 : 0] addra
  .douta(fftconj_300555_data_pncode2check)  // output wire [47 : 0] douta
);




reg s_mult_a_tvalid_pncode2check;

wire [79:0] m_mult_dout_tdata_pncode2check;
wire [32:0] m_mult_dout_tdata_pncode2check_re;
wire [32:0] m_mult_dout_tdata_pncode2check_im;

assign m_mult_dout_tdata_pncode2check_re = m_mult_dout_tdata_pncode2check[32:0];
assign m_mult_dout_tdata_pncode2check_im = m_mult_dout_tdata_pncode2check[72:40];

/* 调试信号 */
/* wire [23:0] fftconj_300555_data_pncode2check_re;
wire [23:0] fftconj_300555_data_pncode2check_im;
wire [23:0] fft_fifo_dout_re;
wire [23:0] fft_fifo_dout_im;


assign fftconj_300555_data_pncode2check_re=fftconj_300555_data_pncode2check[23:0];
assign fftconj_300555_data_pncode2check_im=fftconj_300555_data_pncode2check[47:24];
assign fft_fifo_dout_re =   fft_fifo_dout[23:0];
assign fft_fifo_dout_im =   fft_fifo_dout[47:24]; */

/*调试信号 end */

always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        s_mult_a_tvalid_pncode2check <=  0;
    else 
        s_mult_a_tvalid_pncode2check <=  frame_pncode2_cut_valid;

end

wire m_mult_dout_tvalid_pncode2check;


conj_cmpy_mult conj_cmpy_mult_pncode2check (             
  .aclk(fifo7768_rdclk),                              // input wire aclk
  
  .s_axis_a_tvalid(s_mult_a_tvalid_pncode2check),        // input wire s_axis_a_tvalid
  .s_axis_a_tdata(s_fft_frame_check_data_mult),          // input wire [47 : 0] s_axis_a_tdata
  
  .s_axis_b_tvalid(s_mult_a_tvalid_pncode2check),        // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fftconj_300555_data_pncode2check),          // input wire [47 : 0] s_axis_b_tdata
  
  .m_axis_dout_tvalid(m_mult_dout_tvalid_pncode2check),  // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_mult_dout_tdata_pncode2check)    // output wire [79 : 0] m_axis_dout_tdata
);                                         //乘法器 输出缩放65536倍



wire [79:0] s_ifft_data_tdata_pncode2check;
wire [79:0] m_ifft_Rxy_tdata_pncode2check;
wire m_ifft_Rxy_tvalid_pncode2check;
wire m_ifft_Rxy_tlast_pncode2check;
wire [48:0] m_ifft_Rxy_tdata_pncode2check_re;
wire [48:0] m_ifft_Rxy_tdata_pncode2check_im;

assign s_ifft_data_tdata_pncode2check = {{7'b0,m_mult_dout_tdata_pncode2check_im},{7'b0,m_mult_dout_tdata_pncode2check_re}};
assign m_ifft_Rxy_tdata_pncode2check_re = m_ifft_Rxy_tdata_pncode2check[32:0]<<16;
assign m_ifft_Rxy_tdata_pncode2check_im = m_ifft_Rxy_tdata_pncode2check[72:40]<<16; //左移16位 mult 因乘法器 缩放了65536

/*ifft 调试信号*/
/* wire [32:0] s_ifft_data_tdata_pncode2check_re;
wire [32:0] s_ifft_data_tdata_pncode2check_im;


assign s_ifft_data_tdata_pncode2check_re = s_ifft_data_tdata_pncode2check[32:0];
assign s_ifft_data_tdata_pncode2check_im = s_ifft_data_tdata_pncode2check[72:40];
 */
/*ifft 调试信号 end*/

// /*频谱截断后数据 共轭相乘完 进行 ifft （Rxy(n)）*/
xfft_0 xfft_0_Rxy_ifft_pncode2check (
  .aclk(fifo7768_rdclk),                                                 // input wire aclk
  
  .s_axis_config_tdata(16'b000_011010101010_0),    //最后一位0代表 做ifft 。 缩放256倍，实际无缩放 （ip核不做1/N 计算）   // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_ifft_data_tdata_pncode2check),                      // input wire [79 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(m_mult_dout_tvalid_pncode2check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxy_tdata_pncode2check),                      // output wire [79 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxy_tvalid_pncode2check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_ifft_Rxy_tlast_pncode2check),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);
/* Rxy[n]  ifft 幅值数据*/
reg m_ifft_Rxy_tvalid_pncode2check_r = 0;


wire [97:0] Rxy_abs2_pncode2check_re2part;
wire [97:0] Rxy_abs2_pncode2check_im2part;

mult_gen_0 Rxy_abs2_pncode2check_re2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode2check_re),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode2check_re),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode2check),    // input wire CE
   
   .P(Rxy_abs2_pncode2check_re2part)      // output wire [97 : 0] P
);

mult_gen_0 Rxy_abs2_pncode2check_im2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode2check_im),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode2check_im),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode2check),    // input wire CE
   
   .P(Rxy_abs2_pncode2check_im2part)      // output wire [97 : 0] P
);

reg [79:0] Rxy_abs2_pncode2check_multip;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        Rxy_abs2_pncode2check_multip <=  0;
    else if(state_r!=state)
        Rxy_abs2_pncode2check_multip    <=  0;
    else if(f_cnt_r!=f_cnt)
        Rxy_abs2_pncode2check_multip    <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR||(state==FRAME_P5XOR)))
        if(m_ifft_Rxy_tvalid_pncode2check)
            Rxy_abs2_pncode2check_multip <= Rxy_abs2_pncode2check_re2part+Rxy_abs2_pncode2check_im2part;

end


wire [63:0] Rxy_abs2_pncode2check_dimi65536;
assign Rxy_abs2_pncode2check_dimi65536 = Rxy_abs2_pncode2check_multip >>16;   //缩小65536倍 适配除法器输入位宽

reg fifo_Rxy_abs2_pncode2check_rden = 0;

wire [63:0] fifo_Rxy_abs2_pncode2check_sin_dout;

reg fifo_Rxy_abs2_pncode2check_sin_rst;  //状态变化时 fifo 复位(高电平有效)
always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode2check_sin_rst   <=  1;
    else if(state_r!=state)
        fifo_Rxy_abs2_pncode2check_sin_rst   <=  1;
    else if(f_cnt_r!=f_cnt)
        fifo_Rxy_abs2_pncode2check_sin_rst   <=  1;        
    else
        fifo_Rxy_abs2_pncode2check_sin_rst   <=  0;

end

reg m_ifft_Rxy_tvalid_pncode2check_r2 = 0;
reg m_ifft_Rxy_tvalid_pncode2check_r3 = 0;


fifo_generator_2 fifo_Rxy_abs2_pncode2check_sin (  //将 Rxy_abs2_pncode2check 存到fifo中 等待输入到除法器
  .clk(fifo7768_rdclk),      // input wire clk
  .rst(fifo_Rxy_abs2_pncode2check_sin_rst),    // input wire srst
  
  .din(Rxy_abs2_pncode2check_dimi65536),      // input wire [63 : 0] din
  .wr_en(m_ifft_Rxy_tvalid_pncode2check_r2),  // input wire wr_en
  
  .rd_en(fifo_Rxy_abs2_pncode2check_rden),  // input wire rd_en
  .dout(fifo_Rxy_abs2_pncode2check_sin_dout),    // output wire [63 : 0] dout
  
  .full(),    // output wire full
  .empty()  // output wire empty
);

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode2check 延时一拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode2check_r <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode2check_r <=  m_ifft_Rxy_tvalid_pncode2check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode2check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode2check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode2check_r2 <=  m_ifft_Rxy_tvalid_pncode2check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode2check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode2check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode2check_r3 <=  m_ifft_Rxy_tvalid_pncode2check_r2;
end

reg [79:0]  Rxy_abs2_pncode2check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode2check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode2check_n0 <=  0;
    else if(f_cnt_r != f_cnt)
        Rxy_abs2_pncode2check_n0 <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({m_ifft_Rxy_tvalid_pncode2check_r3,m_ifft_Rxy_tvalid_pncode2check_r2}==2'b01)  //检测到m_ifft_Rxy_tvalid_pncode2check 上升沿，保存Rxy_abs2_pncode2check 的第一个值 
            Rxy_abs2_pncode2check_n0 <=  Rxy_abs2_pncode2check_multip;
end

/* Rxy[n] ifft 幅值数据 end*/

/****   2          end             ****/  
 
 
/* **** 3 计算输入信号 ifft  sqrt_ifft abs ( fft_code1_cut )  **** */ 

wire [47:0] m_ifft_Rxx0_tdata_pncode2check;
wire m_ifft_Rxx0_tvalid_pncode2check;


// /*进行 Rxx(0) ifft 计算*/


xfft_2_Rxx0 xfft_2_Rxx0_pncode2check (
  .aclk(fifo7768_rdclk),    //  input wire aclk
  .s_axis_config_tdata(16'b000_011010101010_0),                  // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_fft_frame_check_data_mult),                      // input wire [47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_mult_a_tvalid_pncode2check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxx0_tdata_pncode2check),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxx0_tvalid_pncode2check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);

/* Rxx0 ifft  sum 幅值数据*/

reg [47:0] fft_sin_cut_abs2_pncode2check_multip = 0;

wire [23:0] m_ifft_Rxx0_tdata_pncode2check_re;
wire [23:0] m_ifft_Rxx0_tdata_pncode2check_im;

assign m_ifft_Rxx0_tdata_pncode2check_re = m_ifft_Rxx0_tdata_pncode2check[23:0];
assign m_ifft_Rxx0_tdata_pncode2check_im = m_ifft_Rxx0_tdata_pncode2check[47:24];

wire [47:0] fft_sin_cut_abs2_pncode2check_repart;
wire [47:0] fft_sin_cut_abs2_pncode2check_impart;

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode2check_repartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode2check_re),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode2check_re),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode2check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode2check_repart)      // output wire [47 : 0] P
);

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode2check_impartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode2check_im),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode2check_im),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode2check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode2check_impart)      // output wire [47 : 0] P
);




always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fft_sin_cut_abs2_pncode2check_multip <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxx0_tvalid_pncode2check)
            fft_sin_cut_abs2_pncode2check_multip <= fft_sin_cut_abs2_pncode2check_repart+fft_sin_cut_abs2_pncode2check_impart;
    else if(state_r != state)
        fft_sin_cut_abs2_pncode2check_multip    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_abs2_pncode2check_multip    <=  0;
end


reg fft_sin_cut_sum_abs2_pncode2check_tvalid = 0;
reg fft_sin_cut_sum_abs2_pncode2check_tvalid_r=0;

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode2check 延时一拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode2check_tvalid <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode2check_tvalid <= m_ifft_Rxx0_tvalid_pncode2check;

end

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode2check 延时2拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode2check_tvalid_r <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode2check_tvalid_r <= fft_sin_cut_sum_abs2_pncode2check_tvalid;

end

reg [47:0]  fft_sin_cut_sum_abs2_pncode2check = 0;
always@(posedge fifo7768_rdclk)begin  //求 sum 即Rxx(0)^2值
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode2check <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(fft_sin_cut_sum_abs2_pncode2check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode2check <=  fft_sin_cut_sum_abs2_pncode2check + fft_sin_cut_abs2_pncode2check_multip;
    else if(state_r != state)
        fft_sin_cut_sum_abs2_pncode2check    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_sum_abs2_pncode2check    <=  0;

end


/*  Rxx0 ifft  sum  幅值数据 end*/
/***** 3         end               ******/ 

/*          归一化互相关函数计算            */ 
reg  flag_Rxy_abs2_pncode2check_d = 0;
always@(posedge fifo7768_rdclk)begin   // Rxy_abs2_pncode2check 计算完成的标志信号
    if(!rstn)
        flag_Rxy_abs2_pncode2check_d <=  0;
    else if(state_r != state)
        flag_Rxy_abs2_pncode2check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_Rxy_abs2_pncode2check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxy_tlast_pncode2check)
            flag_Rxy_abs2_pncode2check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode2check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode2check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode2check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode2check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_fft_sum_abs2_pncode2check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({fft_sin_cut_sum_abs2_pncode2check_tvalid_r,fft_sin_cut_sum_abs2_pncode2check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode2check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode2check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode2check  <=  0;
    else if(state_r!=state)
        cnt_fifo_Rxy_abs2_pncode2check   <=  0;
    else if(f_cnt_r!=f_cnt)
        cnt_fifo_Rxy_abs2_pncode2check   <=  0;        
        
    else if(fifo_Rxy_abs2_pncode2check_rden)
        cnt_fifo_Rxy_abs2_pncode2check  <=  cnt_fifo_Rxy_abs2_pncode2check    +   1;

end 

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode2check_rden  <=  0;
    else if(flag_fft_sum_abs2_pncode2check_d&&flag_Rxy_abs2_pncode2check_d)begin
            if(cnt_fifo_Rxy_abs2_pncode2check>=255)
                fifo_Rxy_abs2_pncode2check_rden  <=  0;
            else
                fifo_Rxy_abs2_pncode2check_rden  <=  1;     end 
    else 
        fifo_Rxy_abs2_pncode2check_rden  <=  0;
            
end



reg s_xcorr_dividend_tvalid_pncode2check = 0;
always@(posedge fifo7768_rdclk)begin     // 对fifo_Rxy_abs2_pncode2check_rden 延时一拍 作为除法器被除数有效信号
    if(!rstn)
        s_xcorr_dividend_tvalid_pncode2check  <=  0;
    else 
        s_xcorr_dividend_tvalid_pncode2check <=fifo_Rxy_abs2_pncode2check_rden;
    
end


reg [63:0] s_xcorr_divisor_tdata_pncode2check = 0;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        s_xcorr_divisor_tdata_pncode2check   <=  0;
    else if(state_r!=state)
        s_xcorr_divisor_tdata_pncode2check   <=  0;
    else case(state)  
            FRAME_P2XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    2:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R660_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    3:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R10100_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    4:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R14140_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    default:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                endcase
            end
            FRAME_P3XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    2:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R660_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    3:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R10100_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    4:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R14140_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    default:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                endcase
            end
            FRAME_P4XOR: begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    2:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R660_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    3:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R10100_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    4:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R14140_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    default:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                endcase
            end
            FRAME_P5XOR:  begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    2:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R660_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    3:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R10100_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    4:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R14140_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                    default:s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
                endcase
            end
            default:s_xcorr_divisor_tdata_pncode2check   <=  0;
        endcase
        
end
    
wire m_xcorr_dout_tvalid_pncode2check;
wire [79:0]m_xcorr_sin_dout_tdata_pncode2check;
wire [63:0] pncode2check_quotient;
wire [10:0] pncode2check_fraction; 
reg m_xcorr_dout_tvalid_pncode2check_r;



div_gen_0 div_gen_0_xcorr_sin_pncode2check (
  .aclk(fifo7768_rdclk),                                      // input wire aclk
  
  .s_axis_divisor_tvalid(s_xcorr_dividend_tvalid_pncode2check),    // input wire s_axis_divisor_tvalid
//  .s_axis_divisor_tready(s_xcorr_sin_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(s_xcorr_divisor_tdata_pncode2check),      // input wire [63 : 0] s_axis_divisor_tdata 除数
  
  .s_axis_dividend_tvalid(s_xcorr_dividend_tvalid_pncode2check),  // input wire s_axis_dividend_tvalid
//  .s_axis_dividend_tready(s_xcorr_sin_dividend_tready),                            // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(fifo_Rxy_abs2_pncode2check_sin_dout),    // input wire [63 : 0] s_axis_dividend_tdata 被除数
  
  .m_axis_dout_tvalid(m_xcorr_dout_tvalid_pncode2check),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_xcorr_sin_dout_tdata_pncode2check)            // output wire [79 : 0] m_axis_dout_tdata
);

assign pncode2check_quotient = m_xcorr_sin_dout_tdata_pncode2check[74:11];
assign pncode2check_fraction = m_xcorr_sin_dout_tdata_pncode2check[10:0];

/*          归一化互相关函数计算  end          */  

/*     确认帧头flag信号    */


always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode2check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode2check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode2check_r    <=  m_xcorr_dout_tvalid_pncode2check;


end

reg m_xcorr_dout_tvalid_pncode2check_r2;

always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode2check 延时2拍
    if(!rstn)
        m_xcorr_dout_tvalid_pncode2check_r2   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode2check_r2    <=  m_xcorr_dout_tvalid_pncode2check_r;


end


(* mark_debug="true" *)reg [10:0] pncode2check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode2check_fraction_max <=  0;
    else if(state_r!=state)
        pncode2check_fraction_max <=  0;
    else if(f_cnt_r!=f_cnt)
        pncode2check_fraction_max <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))begin
        if(m_xcorr_dout_tvalid_pncode2check && (pncode2check_fraction>pncode2check_fraction_max))
           pncode2check_fraction_max<=pncode2check_fraction;
    end

end







/*************    pncode2_check    end      ************/    
/*************    pncode2_check    end      ************/  
/*************    pncode2_check    end      ************/  
/*************    pncode2_check    end      ************/ 





/*************    pncode3_check    begin      ************/    
/*************    pncode3_check    begin      ************/  
/*************    pncode3_check    begin      ************/  
/*************    pncode3_check    begin      ************/  
 
 

reg [15:0] ram_conjdata_addra_pncode3check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode3check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode3check <=  0;
    else if(f_cnt_r!=f_cnt)
        ram_conjdata_addra_pncode3check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode3check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512       ;
                2:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+1024 ;
                3:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+2048 ;
                4:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+3072 ;
                5:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+4096 ;
                6:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+5120 ;
                7:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+6144 ;
                8:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+7168 ;
                9:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+8192 ;
                10:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+9216 ;
                11:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+10240;
                12:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+11264;
                13:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+12288;
                14:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+13312;
                15:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+14336;
                16:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+15360;
                17:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+16384;
                18:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+17408;
                19:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+18432;
                20:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+19456;
                21:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+20480;
                22:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+21504;
                23:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+22528;
                24:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+23552;
                25:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+24576;
                26:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+25600;
                27:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+26624;
                28:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+27648;
                29:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+28672;
                30:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+29696;
                31:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+30720;
                32:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+31744;
                33:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+32768;
                34:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+33792;
                35:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+34816;
                36:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+35840;
                37:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+36864;
                38:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+37888;
                39:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+38912;
                40:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+39936;
                41:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+40960;
                42:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+41984;
                43:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+43008;
                44:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+44032;
                45:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+45056;
                46:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+46080;
                47:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+47104;
                48:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+48128;
                49:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+49152;
                50:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+50176;
                51:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+51200;
                52:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+52224;
                53:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+53248;
                54:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+54272;
                55:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+55296;
                56:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+56320;
                57:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+57344;
                58:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+58368;
                59:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+59392;
                60:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+60416;
                61:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+61440;
                62:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+62464;
                63:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+63488;
                64:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+64512;
            endcase
            end
        FRAME_P3XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512       ;
                2:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+1024 ;
                3:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+2048 ;
                4:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+3072 ;
                5:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+4096 ;
                6:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+5120 ;
                7:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+6144 ;
                8:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+7168 ;
                9:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+8192 ;
                10:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+9216 ;
                11:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+10240;
                12:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+11264;
                13:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+12288;
                14:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+13312;
                15:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+14336;
                16:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+15360;
                17:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+16384;
                18:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+17408;
                19:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+18432;
                20:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+19456;
                21:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+20480;
                22:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+21504;
                23:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+22528;
                24:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+23552;
                25:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+24576;
                26:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+25600;
                27:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+26624;
                28:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+27648;
                29:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+28672;
                30:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+29696;
                31:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+30720;
                32:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+31744;
                33:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+32768;
                34:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+33792;
                35:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+34816;
                36:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+35840;
                37:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+36864;
                38:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+37888;
                39:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+38912;
                40:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+39936;
                41:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+40960;
                42:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+41984;
                43:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+43008;
                44:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+44032;
                45:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+45056;
                46:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+46080;
                47:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+47104;
                48:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+48128;
                49:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+49152;
                50:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+50176;
                51:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+51200;
                52:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+52224;
                53:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+53248;
                54:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+54272;
                55:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+55296;
                56:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+56320;
                57:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+57344;
                58:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+58368;
                59:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+59392;
                60:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+60416;
                61:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+61440;
                62:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+62464;
                63:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+63488;
                64:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+64512;
            endcase
            end
        FRAME_P4XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512       ;
                2:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+1024 ;
                3:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+2048 ;
                4:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+3072 ;
                5:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+4096 ;
                6:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+5120 ;
                7:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+6144 ;
                8:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+7168 ;
                9:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+8192 ;
                10:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+9216 ;
                11:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+10240;
                12:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+11264;
                13:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+12288;
                14:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+13312;
                15:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+14336;
                16:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+15360;
                17:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+16384;
                18:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+17408;
                19:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+18432;
                20:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+19456;
                21:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+20480;
                22:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+21504;
                23:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+22528;
                24:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+23552;
                25:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+24576;
                26:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+25600;
                27:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+26624;
                28:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+27648;
                29:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+28672;
                30:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+29696;
                31:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+30720;
                32:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+31744;
                33:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+32768;
                34:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+33792;
                35:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+34816;
                36:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+35840;
                37:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+36864;
                38:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+37888;
                39:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+38912;
                40:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+39936;
                41:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+40960;
                42:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+41984;
                43:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+43008;
                44:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+44032;
                45:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+45056;
                46:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+46080;
                47:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+47104;
                48:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+48128;
                49:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+49152;
                50:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+50176;
                51:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+51200;
                52:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+52224;
                53:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+53248;
                54:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+54272;
                55:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+55296;
                56:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+56320;
                57:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+57344;
                58:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+58368;
                59:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+59392;
                60:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+60416;
                61:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+61440;
                62:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+62464;
                63:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+63488;
                64:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+64512;
            endcase                              
            end                                  
        FRAME_P5XOR: begin                       
            case(f_cnt)                          
                1:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512       ;
                2:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+1024 ;
                3:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+2048 ;
                4:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+3072 ;
                5:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+4096 ;
                6:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+5120 ;
                7:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+6144 ;
                8:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+7168 ;
                9:      ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+8192 ;
                10:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+9216 ;
                11:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+10240;
                12:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+11264;
                13:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+12288;
                14:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+13312;
                15:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+14336;
                16:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+15360;
                17:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+16384;
                18:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+17408;
                19:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+18432;
                20:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+19456;
                21:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+20480;
                22:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+21504;
                23:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+22528;
                24:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+23552;
                25:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+24576;
                26:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+25600;
                27:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+26624;
                28:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+27648;
                29:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+28672;
                30:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+29696;
                31:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+30720;
                32:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+31744;
                33:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+32768;
                34:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+33792;
                35:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+34816;
                36:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+35840;
                37:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+36864;
                38:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+37888;
                39:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+38912;
                40:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+39936;
                41:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+40960;
                42:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+41984;
                43:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+43008;
                44:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+44032;
                45:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+45056;
                46:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+46080;
                47:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+47104;
                48:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+48128;
                49:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+49152;
                50:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+50176;
                51:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+51200;
                52:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+52224;
                53:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+53248;
                54:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+54272;
                55:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+55296;
                56:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+56320;
                57:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+57344;
                58:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+58368;
                59:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+59392;
                60:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+60416;
                61:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+61440;
                62:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+62464;
                63:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+63488;
                64:     ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+512+64512;
            endcase
            end
        default:ram_conjdata_addra_pncode3check <=  0;
    endcase
      


end

wire [47:0] fftconj_300555_data_pncode3check;


blk_mem_gen_0 fram_pncode3check (
  .clka(fifo7768_rdclk),    // input wire clka
  .ena(frame_pncode2_cut_valid),      // input wire ena
  .addra(ram_conjdata_addra_pncode3check),  // input wire [10 : 0] addra
  .douta(fftconj_300555_data_pncode3check)  // output wire [47 : 0] douta
);




reg s_mult_a_tvalid_pncode3check;

wire [79:0] m_mult_dout_tdata_pncode3check;
wire [32:0] m_mult_dout_tdata_pncode3check_re;
wire [32:0] m_mult_dout_tdata_pncode3check_im;

assign m_mult_dout_tdata_pncode3check_re = m_mult_dout_tdata_pncode3check[32:0];
assign m_mult_dout_tdata_pncode3check_im = m_mult_dout_tdata_pncode3check[72:40];

/* 调试信号 */
/* wire [23:0] fftconj_300555_data_pncode3check_re;
wire [23:0] fftconj_300555_data_pncode3check_im;
wire [23:0] fft_fifo_dout_re;
wire [23:0] fft_fifo_dout_im;


assign fftconj_300555_data_pncode3check_re=fftconj_300555_data_pncode3check[23:0];
assign fftconj_300555_data_pncode3check_im=fftconj_300555_data_pncode3check[47:24];
assign fft_fifo_dout_re =   fft_fifo_dout[23:0];
assign fft_fifo_dout_im =   fft_fifo_dout[47:24]; */

/*调试信号 end */

always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        s_mult_a_tvalid_pncode3check <=  0;
    else 
        s_mult_a_tvalid_pncode3check <=  frame_pncode2_cut_valid;

end

wire m_mult_dout_tvalid_pncode3check;


conj_cmpy_mult conj_cmpy_mult_pncode3check (             
  .aclk(fifo7768_rdclk),                              // input wire aclk
  
  .s_axis_a_tvalid(s_mult_a_tvalid_pncode3check),        // input wire s_axis_a_tvalid
  .s_axis_a_tdata(s_fft_frame_check_data_mult),          // input wire [47 : 0] s_axis_a_tdata
  
  .s_axis_b_tvalid(s_mult_a_tvalid_pncode3check),        // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fftconj_300555_data_pncode3check),          // input wire [47 : 0] s_axis_b_tdata
  
  .m_axis_dout_tvalid(m_mult_dout_tvalid_pncode3check),  // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_mult_dout_tdata_pncode3check)    // output wire [79 : 0] m_axis_dout_tdata
);                                         //乘法器 输出缩放65536倍



wire [79:0] s_ifft_data_tdata_pncode3check;
wire [79:0] m_ifft_Rxy_tdata_pncode3check;
wire m_ifft_Rxy_tvalid_pncode3check;
wire m_ifft_Rxy_tlast_pncode3check;
wire [48:0] m_ifft_Rxy_tdata_pncode3check_re;
wire [48:0] m_ifft_Rxy_tdata_pncode3check_im;

assign s_ifft_data_tdata_pncode3check = {{7'b0,m_mult_dout_tdata_pncode3check_im},{7'b0,m_mult_dout_tdata_pncode3check_re}};
assign m_ifft_Rxy_tdata_pncode3check_re = m_ifft_Rxy_tdata_pncode3check[32:0]<<16;
assign m_ifft_Rxy_tdata_pncode3check_im = m_ifft_Rxy_tdata_pncode3check[72:40]<<16; //左移16位 mult 因乘法器 缩放了65536

/*ifft 调试信号*/
/* wire [32:0] s_ifft_data_tdata_pncode3check_re;
wire [32:0] s_ifft_data_tdata_pncode3check_im;


assign s_ifft_data_tdata_pncode3check_re = s_ifft_data_tdata_pncode3check[32:0];
assign s_ifft_data_tdata_pncode3check_im = s_ifft_data_tdata_pncode3check[72:40];
 */
/*ifft 调试信号 end*/

// /*频谱截断后数据 共轭相乘完 进行 ifft （Rxy(n)）*/
xfft_0 xfft_0_Rxy_ifft_pncode3check (
  .aclk(fifo7768_rdclk),                                                 // input wire aclk
  
  .s_axis_config_tdata(16'b000_011010101010_0),    //最后一位0代表 做ifft 。 缩放256倍，实际无缩放 （ip核不做1/N 计算）   // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_ifft_data_tdata_pncode3check),                      // input wire [79 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(m_mult_dout_tvalid_pncode3check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxy_tdata_pncode3check),                      // output wire [79 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxy_tvalid_pncode3check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_ifft_Rxy_tlast_pncode3check),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);
/* Rxy[n]  ifft 幅值数据*/
reg m_ifft_Rxy_tvalid_pncode3check_r = 0;


wire [97:0] Rxy_abs2_pncode3check_re2part;
wire [97:0] Rxy_abs2_pncode3check_im2part;

mult_gen_0 Rxy_abs2_pncode3check_re2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode3check_re),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode3check_re),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode3check),    // input wire CE
   
   .P(Rxy_abs2_pncode3check_re2part)      // output wire [97 : 0] P
);

mult_gen_0 Rxy_abs2_pncode3check_im2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode3check_im),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode3check_im),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode3check),    // input wire CE
   
   .P(Rxy_abs2_pncode3check_im2part)      // output wire [97 : 0] P
);

reg [79:0] Rxy_abs2_pncode3check_multip;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        Rxy_abs2_pncode3check_multip <=  0;
    else if(state_r!=state)
        Rxy_abs2_pncode3check_multip    <=  0;
    else if(f_cnt_r!=f_cnt)
        Rxy_abs2_pncode3check_multip    <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR||(state==FRAME_P5XOR)))
        if(m_ifft_Rxy_tvalid_pncode3check)
            Rxy_abs2_pncode3check_multip <= Rxy_abs2_pncode3check_re2part+Rxy_abs2_pncode3check_im2part;

end


wire [63:0] Rxy_abs2_pncode3check_dimi65536;
assign Rxy_abs2_pncode3check_dimi65536 = Rxy_abs2_pncode3check_multip >>16;   //缩小65536倍 适配除法器输入位宽

reg fifo_Rxy_abs2_pncode3check_rden = 0;

wire [63:0] fifo_Rxy_abs2_pncode3check_sin_dout;

reg fifo_Rxy_abs2_pncode3check_sin_rst;  //状态变化时 fifo 复位(高电平有效)
always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode3check_sin_rst   <=  1;
    else if(state_r!=state)
        fifo_Rxy_abs2_pncode3check_sin_rst   <=  1;
    else if(f_cnt_r!=f_cnt)
        fifo_Rxy_abs2_pncode3check_sin_rst   <=  1;        
    else
        fifo_Rxy_abs2_pncode3check_sin_rst   <=  0;

end

reg m_ifft_Rxy_tvalid_pncode3check_r2 = 0;
reg m_ifft_Rxy_tvalid_pncode3check_r3 = 0;


fifo_generator_2 fifo_Rxy_abs2_pncode3check_sin (  //将 Rxy_abs2_pncode3check 存到fifo中 等待输入到除法器
  .clk(fifo7768_rdclk),      // input wire clk
  .rst(fifo_Rxy_abs2_pncode3check_sin_rst),    // input wire srst
  
  .din(Rxy_abs2_pncode3check_dimi65536),      // input wire [63 : 0] din
  .wr_en(m_ifft_Rxy_tvalid_pncode3check_r2),  // input wire wr_en
  
  .rd_en(fifo_Rxy_abs2_pncode3check_rden),  // input wire rd_en
  .dout(fifo_Rxy_abs2_pncode3check_sin_dout),    // output wire [63 : 0] dout
  
  .full(),    // output wire full
  .empty()  // output wire empty
);

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode3check 延时一拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode3check_r <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode3check_r <=  m_ifft_Rxy_tvalid_pncode3check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode3check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode3check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode3check_r2 <=  m_ifft_Rxy_tvalid_pncode3check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode3check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode3check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode3check_r3 <=  m_ifft_Rxy_tvalid_pncode3check_r2;
end

reg [79:0]  Rxy_abs2_pncode3check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode3check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode3check_n0 <=  0;
    else if(f_cnt_r != f_cnt)
        Rxy_abs2_pncode3check_n0 <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({m_ifft_Rxy_tvalid_pncode3check_r3,m_ifft_Rxy_tvalid_pncode3check_r2}==2'b01)  //检测到m_ifft_Rxy_tvalid_pncode3check 上升沿，保存Rxy_abs2_pncode3check 的第一个值 
            Rxy_abs2_pncode3check_n0 <=  Rxy_abs2_pncode3check_multip;
end

/* Rxy[n] ifft 幅值数据 end*/

/****   2          end             ****/  
 
 
/* **** 3 计算输入信号 ifft  sqrt_ifft abs ( fft_code1_cut )  **** */ 

wire [47:0] m_ifft_Rxx0_tdata_pncode3check;
wire m_ifft_Rxx0_tvalid_pncode3check;


// /*进行 Rxx(0) ifft 计算*/


xfft_2_Rxx0 xfft_2_Rxx0_pncode3check (
  .aclk(fifo7768_rdclk),    //  input wire aclk
  .s_axis_config_tdata(16'b000_011010101010_0),                  // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_fft_frame_check_data_mult),                      // input wire [47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_mult_a_tvalid_pncode3check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxx0_tdata_pncode3check),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxx0_tvalid_pncode3check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);

/* Rxx0 ifft  sum 幅值数据*/

reg [47:0] fft_sin_cut_abs2_pncode3check_multip = 0;

wire [23:0] m_ifft_Rxx0_tdata_pncode3check_re;
wire [23:0] m_ifft_Rxx0_tdata_pncode3check_im;

assign m_ifft_Rxx0_tdata_pncode3check_re = m_ifft_Rxx0_tdata_pncode3check[23:0];
assign m_ifft_Rxx0_tdata_pncode3check_im = m_ifft_Rxx0_tdata_pncode3check[47:24];

wire [47:0] fft_sin_cut_abs2_pncode3check_repart;
wire [47:0] fft_sin_cut_abs2_pncode3check_impart;

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode3check_repartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode3check_re),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode3check_re),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode3check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode3check_repart)      // output wire [47 : 0] P
);

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode3check_impartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode3check_im),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode3check_im),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode3check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode3check_impart)      // output wire [47 : 0] P
);




always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fft_sin_cut_abs2_pncode3check_multip <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxx0_tvalid_pncode3check)
            fft_sin_cut_abs2_pncode3check_multip <= fft_sin_cut_abs2_pncode3check_repart+fft_sin_cut_abs2_pncode3check_impart;
    else if(state_r != state)
        fft_sin_cut_abs2_pncode3check_multip    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_abs2_pncode3check_multip    <=  0;
end


reg fft_sin_cut_sum_abs2_pncode3check_tvalid = 0;
reg fft_sin_cut_sum_abs2_pncode3check_tvalid_r=0;

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode3check 延时一拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode3check_tvalid <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode3check_tvalid <= m_ifft_Rxx0_tvalid_pncode3check;

end

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode3check 延时2拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode3check_tvalid_r <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode3check_tvalid_r <= fft_sin_cut_sum_abs2_pncode3check_tvalid;

end

reg [47:0]  fft_sin_cut_sum_abs2_pncode3check = 0;
always@(posedge fifo7768_rdclk)begin  //求 sum 即Rxx(0)^2值
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode3check <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(fft_sin_cut_sum_abs2_pncode3check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode3check <=  fft_sin_cut_sum_abs2_pncode3check + fft_sin_cut_abs2_pncode3check_multip;
    else if(state_r != state)
        fft_sin_cut_sum_abs2_pncode3check    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_sum_abs2_pncode3check    <=  0;

end


/*  Rxx0 ifft  sum  幅值数据 end*/
/***** 3         end               ******/ 

/*          归一化互相关函数计算            */ 
reg  flag_Rxy_abs2_pncode3check_d = 0;
always@(posedge fifo7768_rdclk)begin   // Rxy_abs2_pncode3check 计算完成的标志信号
    if(!rstn)
        flag_Rxy_abs2_pncode3check_d <=  0;
    else if(state_r != state)
        flag_Rxy_abs2_pncode3check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_Rxy_abs2_pncode3check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxy_tlast_pncode3check)
            flag_Rxy_abs2_pncode3check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode3check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode3check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode3check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode3check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_fft_sum_abs2_pncode3check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({fft_sin_cut_sum_abs2_pncode3check_tvalid_r,fft_sin_cut_sum_abs2_pncode3check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode3check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode3check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode3check  <=  0;
    else if(state_r!=state)
        cnt_fifo_Rxy_abs2_pncode3check   <=  0;
    else if(f_cnt_r!=f_cnt)
        cnt_fifo_Rxy_abs2_pncode3check   <=  0;        
        
    else if(fifo_Rxy_abs2_pncode3check_rden)
        cnt_fifo_Rxy_abs2_pncode3check  <=  cnt_fifo_Rxy_abs2_pncode3check    +   1;

end 

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode3check_rden  <=  0;
    else if(flag_fft_sum_abs2_pncode3check_d&&flag_Rxy_abs2_pncode3check_d)begin
            if(cnt_fifo_Rxy_abs2_pncode3check>=255)
                fifo_Rxy_abs2_pncode3check_rden  <=  0;
            else
                fifo_Rxy_abs2_pncode3check_rden  <=  1;     end 
    else 
        fifo_Rxy_abs2_pncode3check_rden  <=  0;
            
end



reg s_xcorr_dividend_tvalid_pncode3check = 0;
always@(posedge fifo7768_rdclk)begin     // 对fifo_Rxy_abs2_pncode3check_rden 延时一拍 作为除法器被除数有效信号
    if(!rstn)
        s_xcorr_dividend_tvalid_pncode3check  <=  0;
    else 
        s_xcorr_dividend_tvalid_pncode3check <=fifo_Rxy_abs2_pncode3check_rden;
    
end


reg [63:0] s_xcorr_divisor_tdata_pncode3check = 0;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        s_xcorr_divisor_tdata_pncode3check   <=  0;
    else if(state_r!=state)
        s_xcorr_divisor_tdata_pncode3check   <=  0;
    else case(state)  
            FRAME_P2XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    2:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R770_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    3:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R11110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    4:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R15150_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    default:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                endcase
            end
            FRAME_P3XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    2:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R770_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    3:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R11110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    4:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R15150_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    default:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                endcase
            end
            FRAME_P4XOR: begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    2:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R770_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    3:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R11110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    4:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R15150_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    default:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                endcase
            end
            FRAME_P5XOR:  begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    2:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R770_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    3:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R11110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    4:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R15150_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
                    default:s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
               endcase
            end
            default:s_xcorr_divisor_tdata_pncode3check   <=  0;
        endcase
        
end
    
wire m_xcorr_dout_tvalid_pncode3check;
wire [79:0]m_xcorr_sin_dout_tdata_pncode3check;
wire [63:0] pncode3check_quotient;
wire [10:0] pncode3check_fraction; 
reg m_xcorr_dout_tvalid_pncode3check_r;



div_gen_0 div_gen_0_xcorr_sin_pncode3check (
  .aclk(fifo7768_rdclk),                                      // input wire aclk
  
  .s_axis_divisor_tvalid(s_xcorr_dividend_tvalid_pncode3check),    // input wire s_axis_divisor_tvalid
//  .s_axis_divisor_tready(s_xcorr_sin_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(s_xcorr_divisor_tdata_pncode3check),      // input wire [63 : 0] s_axis_divisor_tdata 除数
  
  .s_axis_dividend_tvalid(s_xcorr_dividend_tvalid_pncode3check),  // input wire s_axis_dividend_tvalid
//  .s_axis_dividend_tready(s_xcorr_sin_dividend_tready),                            // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(fifo_Rxy_abs2_pncode3check_sin_dout),    // input wire [63 : 0] s_axis_dividend_tdata 被除数
  
  .m_axis_dout_tvalid(m_xcorr_dout_tvalid_pncode3check),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_xcorr_sin_dout_tdata_pncode3check)            // output wire [79 : 0] m_axis_dout_tdata
);

assign pncode3check_quotient = m_xcorr_sin_dout_tdata_pncode3check[74:11];
assign pncode3check_fraction = m_xcorr_sin_dout_tdata_pncode3check[10:0];

/*          归一化互相关函数计算  end          */  

/*     确认帧头flag信号    */


always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode3check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode3check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode3check_r    <=  m_xcorr_dout_tvalid_pncode3check;


end

reg m_xcorr_dout_tvalid_pncode3check_r2;

always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode3check 延时2拍
    if(!rstn)
        m_xcorr_dout_tvalid_pncode3check_r2   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode3check_r2    <=  m_xcorr_dout_tvalid_pncode3check_r;


end


(* mark_debug="true" *)reg [10:0] pncode3check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode3check_fraction_max <=  0;
    else if(state_r!=state)
        pncode3check_fraction_max <=  0;
    else if(f_cnt_r!=f_cnt)
        pncode3check_fraction_max <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))begin
        if(m_xcorr_dout_tvalid_pncode3check && (pncode3check_fraction>pncode3check_fraction_max))
           pncode3check_fraction_max<=pncode3check_fraction;
    end

end





/*************    pncode3_check    end      ************/    
/*************    pncode3_check    end      ************/  
/*************    pncode3_check    end      ************/  
/*************    pncode3_check    end      ************/  



/*************    pncode4_check    begin      ************/    
/*************    pncode4_check    begin      ************/  
/*************    pncode4_check    begin      ************/  
/*************    pncode4_check    begin      ************/  




reg [15:0] ram_conjdata_addra_pncode4check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode4check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode4check <=  0;
    else if(f_cnt_r!=f_cnt)
        ram_conjdata_addra_pncode4check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode4check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768       ;
                2:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+1024 ;
                3:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+2048 ;
                4:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+3072 ;
                5:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+4096 ;
                6:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+5120 ;
                7:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+6144 ;
                8:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+7168 ;
                9:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+8192 ;
                10:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+9216 ;
                11:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+10240;
                12:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+11264;
                13:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+12288;
                14:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+13312;
                15:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+14336;
                16:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+15360;
                17:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+16384;
                18:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+17408;
                19:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+18432;
                20:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+19456;
                21:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+20480;
                22:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+21504;
                23:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+22528;
                24:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+23552;
                25:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+24576;
                26:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+25600;
                27:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+26624;
                28:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+27648;
                29:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+28672;
                30:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+29696;
                31:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+30720;
                32:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+31744;
                33:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+32768;
                34:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+33792;
                35:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+34816;
                36:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+35840;
                37:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+36864;
                38:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+37888;
                39:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+38912;
                40:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+39936;
                41:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+40960;
                42:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+41984;
                43:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+43008;
                44:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+44032;
                45:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+45056;
                46:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+46080;
                47:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+47104;
                48:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+48128;
                49:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+49152;
                50:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+50176;
                51:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+51200;
                52:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+52224;
                53:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+53248;
                54:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+54272;
                55:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+55296;
                56:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+56320;
                57:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+57344;
                58:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+58368;
                59:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+59392;
                60:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+60416;
                61:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+61440;
                62:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+62464;
                63:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+63488;
                64:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+64512;
            endcase
            end
        FRAME_P3XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768       ;
                2:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+1024 ;
                3:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+2048 ;
                4:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+3072 ;
                5:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+4096 ;
                6:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+5120 ;
                7:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+6144 ;
                8:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+7168 ;
                9:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+8192 ;
                10:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+9216 ;
                11:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+10240;
                12:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+11264;
                13:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+12288;
                14:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+13312;
                15:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+14336;
                16:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+15360;
                17:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+16384;
                18:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+17408;
                19:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+18432;
                20:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+19456;
                21:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+20480;
                22:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+21504;
                23:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+22528;
                24:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+23552;
                25:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+24576;
                26:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+25600;
                27:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+26624;
                28:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+27648;
                29:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+28672;
                30:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+29696;
                31:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+30720;
                32:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+31744;
                33:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+32768;
                34:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+33792;
                35:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+34816;
                36:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+35840;
                37:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+36864;
                38:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+37888;
                39:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+38912;
                40:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+39936;
                41:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+40960;
                42:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+41984;
                43:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+43008;
                44:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+44032;
                45:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+45056;
                46:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+46080;
                47:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+47104;
                48:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+48128;
                49:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+49152;
                50:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+50176;
                51:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+51200;
                52:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+52224;
                53:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+53248;
                54:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+54272;
                55:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+55296;
                56:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+56320;
                57:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+57344;
                58:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+58368;
                59:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+59392;
                60:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+60416;
                61:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+61440;
                62:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+62464;
                63:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+63488;
                64:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+64512;
            endcase                              
            end                                  
        FRAME_P4XOR: begin                       
            case(f_cnt)                          
                1:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768       ;
                2:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+1024 ;
                3:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+2048 ;
                4:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+3072 ;
                5:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+4096 ;
                6:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+5120 ;
                7:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+6144 ;
                8:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+7168 ;
                9:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+8192 ;
                10:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+9216 ;
                11:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+10240;
                12:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+11264;
                13:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+12288;
                14:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+13312;
                15:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+14336;
                16:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+15360;
                17:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+16384;
                18:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+17408;
                19:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+18432;
                20:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+19456;
                21:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+20480;
                22:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+21504;
                23:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+22528;
                24:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+23552;
                25:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+24576;
                26:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+25600;
                27:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+26624;
                28:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+27648;
                29:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+28672;
                30:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+29696;
                31:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+30720;
                32:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+31744;
                33:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+32768;
                34:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+33792;
                35:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+34816;
                36:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+35840;
                37:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+36864;
                38:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+37888;
                39:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+38912;
                40:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+39936;
                41:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+40960;
                42:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+41984;
                43:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+43008;
                44:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+44032;
                45:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+45056;
                46:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+46080;
                47:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+47104;
                48:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+48128;
                49:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+49152;
                50:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+50176;
                51:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+51200;
                52:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+52224;
                53:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+53248;
                54:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+54272;
                55:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+55296;
                56:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+56320;
                57:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+57344;
                58:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+58368;
                59:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+59392;
                60:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+60416;
                61:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+61440;
                62:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+62464;
                63:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+63488;
                64:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+64512;
            endcase
            end
        FRAME_P5XOR: begin
            case(f_cnt)
                1:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768       ;
                2:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+1024 ;
                3:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+2048 ;
                4:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+3072 ;
                5:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+4096 ;
                6:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+5120 ;
                7:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+6144 ;
                8:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+7168 ;
                9:      ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+8192 ;
                10:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+9216 ;
                11:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+10240;
                12:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+11264;
                13:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+12288;
                14:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+13312;
                15:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+14336;
                16:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+15360;
                17:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+16384;
                18:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+17408;
                19:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+18432;
                20:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+19456;
                21:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+20480;
                22:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+21504;
                23:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+22528;
                24:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+23552;
                25:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+24576;
                26:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+25600;
                27:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+26624;
                28:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+27648;
                29:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+28672;
                30:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+29696;
                31:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+30720;
                32:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+31744;
                33:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+32768;
                34:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+33792;
                35:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+34816;
                36:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+35840;
                37:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+36864;
                38:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+37888;
                39:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+38912;
                40:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+39936;
                41:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+40960;
                42:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+41984;
                43:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+43008;
                44:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+44032;
                45:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+45056;
                46:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+46080;
                47:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+47104;
                48:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+48128;
                49:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+49152;
                50:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+50176;
                51:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+51200;
                52:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+52224;
                53:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+53248;
                54:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+54272;
                55:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+55296;
                56:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+56320;
                57:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+57344;
                58:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+58368;
                59:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+59392;
                60:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+60416;
                61:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+61440;
                62:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+62464;
                63:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+63488;
                64:     ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+768+64512;
            endcase
            end
        default:ram_conjdata_addra_pncode4check <=  0;
    endcase
      


end

wire [47:0] fftconj_300555_data_pncode4check;


blk_mem_gen_0 fram_pncode4check (
  .clka(fifo7768_rdclk),    // input wire clka
  .ena(frame_pncode2_cut_valid),      // input wire ena
  .addra(ram_conjdata_addra_pncode4check),  // input wire [10 : 0] addra
  .douta(fftconj_300555_data_pncode4check)  // output wire [47 : 0] douta
);




reg s_mult_a_tvalid_pncode4check;

wire [79:0] m_mult_dout_tdata_pncode4check;
wire [32:0] m_mult_dout_tdata_pncode4check_re;
wire [32:0] m_mult_dout_tdata_pncode4check_im;

assign m_mult_dout_tdata_pncode4check_re = m_mult_dout_tdata_pncode4check[32:0];
assign m_mult_dout_tdata_pncode4check_im = m_mult_dout_tdata_pncode4check[72:40];

/* 调试信号 */
/* wire [23:0] fftconj_300555_data_pncode4check_re;
wire [23:0] fftconj_300555_data_pncode4check_im;
wire [23:0] fft_fifo_dout_re;
wire [23:0] fft_fifo_dout_im;


assign fftconj_300555_data_pncode4check_re=fftconj_300555_data_pncode4check[23:0];
assign fftconj_300555_data_pncode4check_im=fftconj_300555_data_pncode4check[47:24];
assign fft_fifo_dout_re =   fft_fifo_dout[23:0];
assign fft_fifo_dout_im =   fft_fifo_dout[47:24]; */

/*调试信号 end */

always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        s_mult_a_tvalid_pncode4check <=  0;
    else 
        s_mult_a_tvalid_pncode4check <=  frame_pncode2_cut_valid;

end

wire m_mult_dout_tvalid_pncode4check;


conj_cmpy_mult conj_cmpy_mult_pncode4check (             
  .aclk(fifo7768_rdclk),                              // input wire aclk
  
  .s_axis_a_tvalid(s_mult_a_tvalid_pncode4check),        // input wire s_axis_a_tvalid
  .s_axis_a_tdata(s_fft_frame_check_data_mult),          // input wire [47 : 0] s_axis_a_tdata
  
  .s_axis_b_tvalid(s_mult_a_tvalid_pncode4check),        // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fftconj_300555_data_pncode4check),          // input wire [47 : 0] s_axis_b_tdata
  
  .m_axis_dout_tvalid(m_mult_dout_tvalid_pncode4check),  // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_mult_dout_tdata_pncode4check)    // output wire [79 : 0] m_axis_dout_tdata
);                                         //乘法器 输出缩放65536倍



wire [79:0] s_ifft_data_tdata_pncode4check;
wire [79:0] m_ifft_Rxy_tdata_pncode4check;
wire m_ifft_Rxy_tvalid_pncode4check;
wire m_ifft_Rxy_tlast_pncode4check;
wire [48:0] m_ifft_Rxy_tdata_pncode4check_re;
wire [48:0] m_ifft_Rxy_tdata_pncode4check_im;

assign s_ifft_data_tdata_pncode4check = {{7'b0,m_mult_dout_tdata_pncode4check_im},{7'b0,m_mult_dout_tdata_pncode4check_re}};
assign m_ifft_Rxy_tdata_pncode4check_re = m_ifft_Rxy_tdata_pncode4check[32:0]<<16;
assign m_ifft_Rxy_tdata_pncode4check_im = m_ifft_Rxy_tdata_pncode4check[72:40]<<16; //左移16位 mult 因乘法器 缩放了65536

/*ifft 调试信号*/
/* wire [32:0] s_ifft_data_tdata_pncode4check_re;
wire [32:0] s_ifft_data_tdata_pncode4check_im;


assign s_ifft_data_tdata_pncode4check_re = s_ifft_data_tdata_pncode4check[32:0];
assign s_ifft_data_tdata_pncode4check_im = s_ifft_data_tdata_pncode4check[72:40];
 */
/*ifft 调试信号 end*/

// /*频谱截断后数据 共轭相乘完 进行 ifft （Rxy(n)）*/
xfft_0 xfft_0_Rxy_ifft_pncode4check (
  .aclk(fifo7768_rdclk),                                                 // input wire aclk
  
  .s_axis_config_tdata(16'b000_011010101010_0),    //最后一位0代表 做ifft 。 缩放256倍，实际无缩放 （ip核不做1/N 计算）   // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_ifft_data_tdata_pncode4check),                      // input wire [79 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(m_mult_dout_tvalid_pncode4check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxy_tdata_pncode4check),                      // output wire [79 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxy_tvalid_pncode4check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_ifft_Rxy_tlast_pncode4check),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);
/* Rxy[n]  ifft 幅值数据*/
reg m_ifft_Rxy_tvalid_pncode4check_r = 0;


wire [97:0] Rxy_abs2_pncode4check_re2part;
wire [97:0] Rxy_abs2_pncode4check_im2part;

mult_gen_0 Rxy_abs2_pncode4check_re2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode4check_re),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode4check_re),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode4check),    // input wire CE
   
   .P(Rxy_abs2_pncode4check_re2part)      // output wire [97 : 0] P
);

mult_gen_0 Rxy_abs2_pncode4check_im2partip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxy_tdata_pncode4check_im),      // input wire [48 : 0] A
  .B(m_ifft_Rxy_tdata_pncode4check_im),      // input wire [48 : 0] B
  .CE(m_ifft_Rxy_tvalid_pncode4check),    // input wire CE
   
   .P(Rxy_abs2_pncode4check_im2part)      // output wire [97 : 0] P
);

reg [79:0] Rxy_abs2_pncode4check_multip;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        Rxy_abs2_pncode4check_multip <=  0;
    else if(state_r!=state)
        Rxy_abs2_pncode4check_multip    <=  0;
    else if(f_cnt_r!=f_cnt)
        Rxy_abs2_pncode4check_multip    <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR||(state==FRAME_P5XOR)))
        if(m_ifft_Rxy_tvalid_pncode4check)
            Rxy_abs2_pncode4check_multip <= Rxy_abs2_pncode4check_re2part+Rxy_abs2_pncode4check_im2part;

end


wire [63:0] Rxy_abs2_pncode4check_dimi65536;
assign Rxy_abs2_pncode4check_dimi65536 = Rxy_abs2_pncode4check_multip >>16;   //缩小65536倍 适配除法器输入位宽

reg fifo_Rxy_abs2_pncode4check_rden = 0;

wire [63:0] fifo_Rxy_abs2_pncode4check_sin_dout;

reg fifo_Rxy_abs2_pncode4check_sin_rst;  //状态变化时 fifo 复位(高电平有效)
always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode4check_sin_rst   <=  1;
    else if(state_r!=state)
        fifo_Rxy_abs2_pncode4check_sin_rst   <=  1;
    else if(f_cnt_r!=f_cnt)
        fifo_Rxy_abs2_pncode4check_sin_rst   <=  1;        
    else
        fifo_Rxy_abs2_pncode4check_sin_rst   <=  0;

end

reg m_ifft_Rxy_tvalid_pncode4check_r2 = 0;
reg m_ifft_Rxy_tvalid_pncode4check_r3 = 0;


fifo_generator_2 fifo_Rxy_abs2_pncode4check_sin (  //将 Rxy_abs2_pncode4check 存到fifo中 等待输入到除法器
  .clk(fifo7768_rdclk),      // input wire clk
  .rst(fifo_Rxy_abs2_pncode4check_sin_rst),    // input wire srst
  
  .din(Rxy_abs2_pncode4check_dimi65536),      // input wire [63 : 0] din
  .wr_en(m_ifft_Rxy_tvalid_pncode4check_r2),  // input wire wr_en
  
  .rd_en(fifo_Rxy_abs2_pncode4check_rden),  // input wire rd_en
  .dout(fifo_Rxy_abs2_pncode4check_sin_dout),    // output wire [63 : 0] dout
  
  .full(),    // output wire full
  .empty()  // output wire empty
);

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode4check 延时一拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode4check_r <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode4check_r <=  m_ifft_Rxy_tvalid_pncode4check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode4check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode4check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode4check_r2 <=  m_ifft_Rxy_tvalid_pncode4check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode4check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode4check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        m_ifft_Rxy_tvalid_pncode4check_r3 <=  m_ifft_Rxy_tvalid_pncode4check_r2;
end

reg [79:0]  Rxy_abs2_pncode4check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode4check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode4check_n0 <=  0;
    else if(f_cnt_r != f_cnt)
        Rxy_abs2_pncode4check_n0 <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({m_ifft_Rxy_tvalid_pncode4check_r3,m_ifft_Rxy_tvalid_pncode4check_r2}==2'b01)  //检测到m_ifft_Rxy_tvalid_pncode4check 上升沿，保存Rxy_abs2_pncode4check 的第一个值 
            Rxy_abs2_pncode4check_n0 <=  Rxy_abs2_pncode4check_multip;
end

/* Rxy[n] ifft 幅值数据 end*/

/****   2          end             ****/  
 
 
/* **** 3 计算输入信号 ifft  sqrt_ifft abs ( fft_code1_cut )  **** */ 

wire [47:0] m_ifft_Rxx0_tdata_pncode4check;
wire m_ifft_Rxx0_tvalid_pncode4check;


// /*进行 Rxx(0) ifft 计算*/


xfft_2_Rxx0 xfft_2_Rxx0_pncode4check (
  .aclk(fifo7768_rdclk),    //  input wire aclk
  .s_axis_config_tdata(16'b000_011010101010_0),                  // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                // input wire s_axis_config_tvalid
  .s_axis_config_tready(),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(s_fft_frame_check_data_mult),                      // input wire [47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_mult_a_tvalid_pncode4check),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(m_ifft_Rxx0_tdata_pncode4check),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_ifft_Rxx0_tvalid_pncode4check),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(),                      // output wire m_axis_data_tlast
  
  .event_frame_started(),                  // output wire event_frame_started
  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
  .event_tlast_missing(),                  // output wire event_tlast_missing
  .event_status_channel_halt(),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
);

/* Rxx0 ifft  sum 幅值数据*/

reg [47:0] fft_sin_cut_abs2_pncode4check_multip = 0;

wire [23:0] m_ifft_Rxx0_tdata_pncode4check_re;
wire [23:0] m_ifft_Rxx0_tdata_pncode4check_im;

assign m_ifft_Rxx0_tdata_pncode4check_re = m_ifft_Rxx0_tdata_pncode4check[23:0];
assign m_ifft_Rxx0_tdata_pncode4check_im = m_ifft_Rxx0_tdata_pncode4check[47:24];

wire [47:0] fft_sin_cut_abs2_pncode4check_repart;
wire [47:0] fft_sin_cut_abs2_pncode4check_impart;

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode4check_repartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode4check_re),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode4check_re),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode4check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode4check_repart)      // output wire [47 : 0] P
);

mult_gen_sincut_abs2 fft_sin_cut_abs2_pncode4check_impartip (
  .CLK(fifo7768_rdclk),  // input wire CLK
  .A(m_ifft_Rxx0_tdata_pncode4check_im),      // input wire [23 : 0] A
  .B(m_ifft_Rxx0_tdata_pncode4check_im),      // input wire [23 : 0] B
  .CE(m_ifft_Rxx0_tvalid_pncode4check),    // input wire CE
  
  
  .P(fft_sin_cut_abs2_pncode4check_impart)      // output wire [47 : 0] P
);




always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fft_sin_cut_abs2_pncode4check_multip <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxx0_tvalid_pncode4check)
            fft_sin_cut_abs2_pncode4check_multip <= fft_sin_cut_abs2_pncode4check_repart+fft_sin_cut_abs2_pncode4check_impart;
    else if(state_r != state)
        fft_sin_cut_abs2_pncode4check_multip    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_abs2_pncode4check_multip    <=  0;
end


reg fft_sin_cut_sum_abs2_pncode4check_tvalid = 0;
reg fft_sin_cut_sum_abs2_pncode4check_tvalid_r=0;

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode4check 延时一拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode4check_tvalid <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode4check_tvalid <= m_ifft_Rxx0_tvalid_pncode4check;

end

always@(posedge fifo7768_rdclk)begin   //对m_ifft_Rxx0_tvalid_pncode4check 延时2拍作为 模值^2 累加有效 信号
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode4check_tvalid_r <=  0;
    else 
        fft_sin_cut_sum_abs2_pncode4check_tvalid_r <= fft_sin_cut_sum_abs2_pncode4check_tvalid;

end

reg [47:0]  fft_sin_cut_sum_abs2_pncode4check = 0;
always@(posedge fifo7768_rdclk)begin  //求 sum 即Rxx(0)^2值
    if(!rstn)
        fft_sin_cut_sum_abs2_pncode4check <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(fft_sin_cut_sum_abs2_pncode4check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode4check <=  fft_sin_cut_sum_abs2_pncode4check + fft_sin_cut_abs2_pncode4check_multip;
    else if(state_r != state)
        fft_sin_cut_sum_abs2_pncode4check    <=  0;
    else if(f_cnt_r != f_cnt)
        fft_sin_cut_sum_abs2_pncode4check    <=  0;

end


/*  Rxx0 ifft  sum  幅值数据 end*/
/***** 3         end               ******/ 

/*          归一化互相关函数计算            */ 
reg  flag_Rxy_abs2_pncode4check_d = 0;
always@(posedge fifo7768_rdclk)begin   // Rxy_abs2_pncode4check 计算完成的标志信号
    if(!rstn)
        flag_Rxy_abs2_pncode4check_d <=  0;
    else if(state_r != state)
        flag_Rxy_abs2_pncode4check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_Rxy_abs2_pncode4check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(m_ifft_Rxy_tlast_pncode4check)
            flag_Rxy_abs2_pncode4check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode4check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode4check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode4check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode4check_d <=  0;
    else if(f_cnt_r != f_cnt)
        flag_fft_sum_abs2_pncode4check_d <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if({fft_sin_cut_sum_abs2_pncode4check_tvalid_r,fft_sin_cut_sum_abs2_pncode4check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode4check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode4check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode4check  <=  0;
    else if(state_r!=state)
        cnt_fifo_Rxy_abs2_pncode4check   <=  0;
    else if(f_cnt_r!=f_cnt)
        cnt_fifo_Rxy_abs2_pncode4check   <=  0;        
        
    else if(fifo_Rxy_abs2_pncode4check_rden)
        cnt_fifo_Rxy_abs2_pncode4check  <=  cnt_fifo_Rxy_abs2_pncode4check    +   1;

end 

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        fifo_Rxy_abs2_pncode4check_rden  <=  0;
    else if(flag_fft_sum_abs2_pncode4check_d&&flag_Rxy_abs2_pncode4check_d)begin
            if(cnt_fifo_Rxy_abs2_pncode4check>=255)
                fifo_Rxy_abs2_pncode4check_rden  <=  0;
            else
                fifo_Rxy_abs2_pncode4check_rden  <=  1;     end 
    else 
        fifo_Rxy_abs2_pncode4check_rden  <=  0;
            
end



reg s_xcorr_dividend_tvalid_pncode4check = 0;
always@(posedge fifo7768_rdclk)begin     // 对fifo_Rxy_abs2_pncode4check_rden 延时一拍 作为除法器被除数有效信号
    if(!rstn)
        s_xcorr_dividend_tvalid_pncode4check  <=  0;
    else 
        s_xcorr_dividend_tvalid_pncode4check <=fifo_Rxy_abs2_pncode4check_rden;
    
end


reg [63:0] s_xcorr_divisor_tdata_pncode4check = 0;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        s_xcorr_divisor_tdata_pncode4check   <=  0;
    else if(state_r!=state)
        s_xcorr_divisor_tdata_pncode4check   <=  0;
    else case(state)  
            FRAME_P2XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    2:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R880_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    3:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R12120_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    4:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R16160_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    default:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                endcase
            end
            FRAME_P3XOR:begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    2:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R880_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    3:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R12120_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    4:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R16160_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                     default:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                endcase
            end
            FRAME_P4XOR: begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    2:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R880_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    3:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R12120_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    4:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R16160_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                     default:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                endcase
            end
            FRAME_P5XOR:  begin 
                case(f_cnt)
                    1:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    2:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R880_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    3:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R12120_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                    4:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R16160_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
                     default:s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
               endcase
            end
            default:s_xcorr_divisor_tdata_pncode4check   <=  0;
        endcase
        
end
    
wire m_xcorr_dout_tvalid_pncode4check;
wire [79:0]m_xcorr_sin_dout_tdata_pncode4check;
wire [63:0] pncode4check_quotient;
wire [10:0] pncode4check_fraction; 
reg m_xcorr_dout_tvalid_pncode4check_r;



div_gen_0 div_gen_0_xcorr_sin_pncode4check (
  .aclk(fifo7768_rdclk),                                      // input wire aclk
  
  .s_axis_divisor_tvalid(s_xcorr_dividend_tvalid_pncode4check),    // input wire s_axis_divisor_tvalid
//  .s_axis_divisor_tready(s_xcorr_sin_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(s_xcorr_divisor_tdata_pncode4check),      // input wire [63 : 0] s_axis_divisor_tdata 除数
  
  .s_axis_dividend_tvalid(s_xcorr_dividend_tvalid_pncode4check),  // input wire s_axis_dividend_tvalid
//  .s_axis_dividend_tready(s_xcorr_sin_dividend_tready),                            // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(fifo_Rxy_abs2_pncode4check_sin_dout),    // input wire [63 : 0] s_axis_dividend_tdata 被除数
  
  .m_axis_dout_tvalid(m_xcorr_dout_tvalid_pncode4check),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_xcorr_sin_dout_tdata_pncode4check)            // output wire [79 : 0] m_axis_dout_tdata
);

assign pncode4check_quotient = m_xcorr_sin_dout_tdata_pncode4check[74:11];
assign pncode4check_fraction = m_xcorr_sin_dout_tdata_pncode4check[10:0];

/*          归一化互相关函数计算  end          */  

/*     确认帧头flag信号    */


always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode4check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode4check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode4check_r    <=  m_xcorr_dout_tvalid_pncode4check;


end

reg m_xcorr_dout_tvalid_pncode4check_r2;

always@(posedge fifo7768_rdclk)begin //对m_xcorr_dout_tvalid_pncode4check 延时2拍
    if(!rstn)
        m_xcorr_dout_tvalid_pncode4check_r2   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode4check_r2    <=  m_xcorr_dout_tvalid_pncode4check_r;


end


(* mark_debug="true" *)reg [10:0] pncode4check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode4check_fraction_max <=  0;
    else if(state_r!=state)
        pncode4check_fraction_max <=  0;
    else if(f_cnt_r!=f_cnt)
        pncode4check_fraction_max <=  0;        
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))begin
        if(m_xcorr_dout_tvalid_pncode4check && (pncode4check_fraction>pncode4check_fraction_max))
           pncode4check_fraction_max<=pncode4check_fraction;
    end

end





/*************    pncode4_check    end      ************/    
/*************    pncode4_check    end      ************/  
/*************    pncode4_check    end      ************/  
/*************    pncode4_check    end      ************/  


/*************    frame jiegou      ************/ 


always@(posedge fifo7768_rdclk)begin
    if(!rstn)begin
        frame_p2jiegou   <=  0;
        end
    else if(state==FRAME_P2XOR)begin
        if({m_xcorr_dout_tvalid_pncode1check_r,m_xcorr_dout_tvalid_pncode1check}==2'b10)begin
            if(pncode1check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p2jiegou   <=  1   -1;
                    2:      frame_p2jiegou   <=  5   -1;
                    3:      frame_p2jiegou   <=  9   -1;
                    4:      frame_p2jiegou   <=  13  -1;
                    5:      frame_p2jiegou   <=  17  -1;              
                    6:      frame_p2jiegou   <=  21  -1;              
                    7:      frame_p2jiegou   <=  25  -1;              
                    8:      frame_p2jiegou   <=  29  -1;              
                    9:      frame_p2jiegou   <=  33  -1;              
                    10:     frame_p2jiegou   <=  37  -1;              
                    11:     frame_p2jiegou   <=  41  -1;              
                    12:     frame_p2jiegou   <=  45  -1;              
                    13:     frame_p2jiegou   <=  49  -1;              
                    14:     frame_p2jiegou   <=  53  -1;              
                    15:     frame_p2jiegou   <=  57  -1;              
                    16:     frame_p2jiegou   <=  61  -1;              
                    17:     frame_p2jiegou   <=  65  -1;              
                    18:     frame_p2jiegou   <=  69  -1;              
                    19:     frame_p2jiegou   <=  73  -1;              
                    20:     frame_p2jiegou   <=  77  -1;              
                    21:     frame_p2jiegou   <=  81  -1;              
                    22:     frame_p2jiegou   <=  85  -1;              
                    23:     frame_p2jiegou   <=  89  -1;              
                    24:     frame_p2jiegou   <=  93  -1;              
                    25:     frame_p2jiegou   <=  97  -1;              
                    26:     frame_p2jiegou   <=  101 -1;               
                    27:     frame_p2jiegou   <=  105 -1;               
                    28:     frame_p2jiegou   <=  109 -1;               
                    29:     frame_p2jiegou   <=  113 -1;               
                    30:     frame_p2jiegou   <=  117 -1;               
                    31:     frame_p2jiegou   <=  121 -1;               
                    32:     frame_p2jiegou   <=  125 -1;               
                    33:     frame_p2jiegou   <=  129 -1;               
                    34:     frame_p2jiegou   <=  133 -1;               
                    35:     frame_p2jiegou   <=  137 -1;               
                    36:     frame_p2jiegou   <=  141 -1;               
                    37:     frame_p2jiegou   <=  145 -1;               
                    38:     frame_p2jiegou   <=  149 -1;               
                    39:     frame_p2jiegou   <=  153 -1;               
                    40:     frame_p2jiegou   <=  157 -1;               
                    41:     frame_p2jiegou   <=  161 -1;               
                    42:     frame_p2jiegou   <=  165 -1;               
                    43:     frame_p2jiegou   <=  169 -1;               
                    44:     frame_p2jiegou   <=  173 -1;               
                    45:     frame_p2jiegou   <=  177 -1;               
                    46:     frame_p2jiegou   <=  181 -1;               
                    47:     frame_p2jiegou   <=  185 -1;               
                    48:     frame_p2jiegou   <=  189 -1;               
                    49:     frame_p2jiegou   <=  193 -1;               
                    50:     frame_p2jiegou   <=  197 -1;               
                    51:     frame_p2jiegou   <=  201 -1;               
                    52:     frame_p2jiegou   <=  205 -1;               
                    53:     frame_p2jiegou   <=  209 -1;               
                    54:     frame_p2jiegou   <=  213 -1;               
                    55:     frame_p2jiegou   <=  217 -1;               
                    56:     frame_p2jiegou   <=  221 -1;               
                    57:     frame_p2jiegou   <=  225 -1;               
                    58:     frame_p2jiegou   <=  229 -1;               
                    59:     frame_p2jiegou   <=  233 -1;               
                    60:     frame_p2jiegou   <=  237 -1;               
                    61:     frame_p2jiegou   <=  241 -1;               
                    62:     frame_p2jiegou   <=  245 -1;               
                    63:     frame_p2jiegou   <=  249 -1;               
                    64:     frame_p2jiegou   <=  253 -1;               
                    
               
                    
                endcase
            end
            
            else if(pncode2check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p2jiegou   <=  2   -1   ;
                    2:      frame_p2jiegou   <=  6   -1   ;
                    3:      frame_p2jiegou   <=  10  -1;
                    4:      frame_p2jiegou   <=  14  -1;
                    5:      frame_p2jiegou   <=  18  -1;              
                    6:      frame_p2jiegou   <=  22  -1;              
                    7:      frame_p2jiegou   <=  26  -1;              
                    8:      frame_p2jiegou   <=  30  -1;              
                    9:      frame_p2jiegou   <=  34  -1;              
                    10:     frame_p2jiegou   <=  38  -1;              
                    11:     frame_p2jiegou   <=  42  -1;              
                    12:     frame_p2jiegou   <=  46  -1;              
                    13:     frame_p2jiegou   <=  50  -1;              
                    14:     frame_p2jiegou   <=  54  -1;              
                    15:     frame_p2jiegou   <=  58  -1;              
                    16:     frame_p2jiegou   <=  62  -1;              
                    17:     frame_p2jiegou   <=  66  -1;              
                    18:     frame_p2jiegou   <=  70  -1;              
                    19:     frame_p2jiegou   <=  74  -1;              
                    20:     frame_p2jiegou   <=  78  -1;              
                    21:     frame_p2jiegou   <=  82  -1;              
                    22:     frame_p2jiegou   <=  86  -1;              
                    23:     frame_p2jiegou   <=  90  -1;              
                    24:     frame_p2jiegou   <=  94  -1;              
                    25:     frame_p2jiegou   <=  98  -1;              
                    26:     frame_p2jiegou   <=  102 -1 ;               
                    27:     frame_p2jiegou   <=  106 -1 ;               
                    28:     frame_p2jiegou   <=  110 -1 ;               
                    29:     frame_p2jiegou   <=  114 -1 ;               
                    30:     frame_p2jiegou   <=  118 -1 ;               
                    31:     frame_p2jiegou   <=  122 -1 ;               
                    32:     frame_p2jiegou   <=  126 -1 ;               
                    33:     frame_p2jiegou   <=  130 -1 ;               
                    34:     frame_p2jiegou   <=  134 -1 ;               
                    35:     frame_p2jiegou   <=  138 -1 ;               
                    36:     frame_p2jiegou   <=  142 -1 ;               
                    37:     frame_p2jiegou   <=  146 -1 ;               
                    38:     frame_p2jiegou   <=  150 -1 ;               
                    39:     frame_p2jiegou   <=  154 -1 ;               
                    40:     frame_p2jiegou   <=  158 -1 ;               
                    41:     frame_p2jiegou   <=  162 -1 ;               
                    42:     frame_p2jiegou   <=  166 -1 ;               
                    43:     frame_p2jiegou   <=  170 -1 ;               
                    44:     frame_p2jiegou   <=  174 -1 ;               
                    45:     frame_p2jiegou   <=  178 -1 ;               
                    46:     frame_p2jiegou   <=  182 -1 ;               
                    47:     frame_p2jiegou   <=  186 -1 ;               
                    48:     frame_p2jiegou   <=  190 -1 ;               
                    49:     frame_p2jiegou   <=  194 -1 ;               
                    50:     frame_p2jiegou   <=  198 -1 ;               
                    51:     frame_p2jiegou   <=  202 -1 ;               
                    52:     frame_p2jiegou   <=  206 -1 ;               
                    53:     frame_p2jiegou   <=  210 -1 ;               
                    54:     frame_p2jiegou   <=  214 -1 ;               
                    55:     frame_p2jiegou   <=  218 -1 ;               
                    56:     frame_p2jiegou   <=  222 -1 ;               
                    57:     frame_p2jiegou   <=  226 -1 ;               
                    58:     frame_p2jiegou   <=  230 -1 ;               
                    59:     frame_p2jiegou   <=  234 -1 ;               
                    60:     frame_p2jiegou   <=  238 -1 ;               
                    61:     frame_p2jiegou   <=  242 -1 ;               
                    62:     frame_p2jiegou   <=  246 -1 ;               
                    63:     frame_p2jiegou   <=  250 -1 ;               
                    64:     frame_p2jiegou   <=  254 -1 ;   
                endcase
            end

        
            else if(pncode3check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p2jiegou   <=  3   -1   ;
                    2:      frame_p2jiegou   <=  7   -1   ;
                    3:      frame_p2jiegou   <=  11  -1   ;
                    4:      frame_p2jiegou   <=  15  -1   ;
                    5:      frame_p2jiegou   <=  19  -1   ;              
                    6:      frame_p2jiegou   <=  23  -1   ;              
                    7:      frame_p2jiegou   <=  27  -1   ;              
                    8:      frame_p2jiegou   <=  31  -1   ;              
                    9:      frame_p2jiegou   <=  35  -1   ;              
                    10:     frame_p2jiegou   <=  39  -1   ;              
                    11:     frame_p2jiegou   <=  43  -1   ;              
                    12:     frame_p2jiegou   <=  47  -1   ;              
                    13:     frame_p2jiegou   <=  51  -1   ;              
                    14:     frame_p2jiegou   <=  55  -1   ;              
                    15:     frame_p2jiegou   <=  59  -1   ;              
                    16:     frame_p2jiegou   <=  63  -1   ;              
                    17:     frame_p2jiegou   <=  67  -1   ;              
                    18:     frame_p2jiegou   <=  71  -1   ;              
                    19:     frame_p2jiegou   <=  75  -1   ;              
                    20:     frame_p2jiegou   <=  79  -1   ;              
                    21:     frame_p2jiegou   <=  83  -1   ;              
                    22:     frame_p2jiegou   <=  87  -1   ;              
                    23:     frame_p2jiegou   <=  91  -1   ;              
                    24:     frame_p2jiegou   <=  95  -1   ;              
                    25:     frame_p2jiegou   <=  99  -1   ;              
                    26:     frame_p2jiegou   <=  103 -1 ;               
                    27:     frame_p2jiegou   <=  107 -1 ;               
                    28:     frame_p2jiegou   <=  111 -1 ;               
                    29:     frame_p2jiegou   <=  115 -1 ;               
                    30:     frame_p2jiegou   <=  119 -1 ;               
                    31:     frame_p2jiegou   <=  123 -1 ;               
                    32:     frame_p2jiegou   <=  127 -1 ;               
                    33:     frame_p2jiegou   <=  131 -1 ;               
                    34:     frame_p2jiegou   <=  135 -1 ;               
                    35:     frame_p2jiegou   <=  139 -1 ;               
                    36:     frame_p2jiegou   <=  143 -1 ;               
                    37:     frame_p2jiegou   <=  147 -1 ;               
                    38:     frame_p2jiegou   <=  151 -1 ;               
                    39:     frame_p2jiegou   <=  155 -1 ;               
                    40:     frame_p2jiegou   <=  159 -1 ;               
                    41:     frame_p2jiegou   <=  163 -1 ;               
                    42:     frame_p2jiegou   <=  167 -1 ;               
                    43:     frame_p2jiegou   <=  171 -1 ;               
                    44:     frame_p2jiegou   <=  175 -1 ;               
                    45:     frame_p2jiegou   <=  179 -1 ;               
                    46:     frame_p2jiegou   <=  183 -1 ;               
                    47:     frame_p2jiegou   <=  187 -1 ;               
                    48:     frame_p2jiegou   <=  191 -1 ;               
                    49:     frame_p2jiegou   <=  195 -1 ;               
                    50:     frame_p2jiegou   <=  199 -1 ;               
                    51:     frame_p2jiegou   <=  203 -1 ;               
                    52:     frame_p2jiegou   <=  207 -1 ;               
                    53:     frame_p2jiegou   <=  211 -1 ;               
                    54:     frame_p2jiegou   <=  215 -1 ;               
                    55:     frame_p2jiegou   <=  219 -1 ;               
                    56:     frame_p2jiegou   <=  223 -1 ;               
                    57:     frame_p2jiegou   <=  227 -1 ;               
                    58:     frame_p2jiegou   <=  231 -1 ;               
                    59:     frame_p2jiegou   <=  235 -1 ;               
                    60:     frame_p2jiegou   <=  239 -1 ;               
                    61:     frame_p2jiegou   <=  243 -1 ;               
                    62:     frame_p2jiegou   <=  247 -1 ;               
                    63:     frame_p2jiegou   <=  251 -1 ;               
                    64:     frame_p2jiegou   <=  255 -1 ;   
                endcase
            end

 
        
            else if(pncode4check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p2jiegou   <=  4   -1   ;
                    2:      frame_p2jiegou   <=  8   -1   ;
                    3:      frame_p2jiegou   <=  12  -1   ;
                    4:      frame_p2jiegou   <=  16  -1   ;
                    5:      frame_p2jiegou   <=  20  -1   ;              
                    6:      frame_p2jiegou   <=  24  -1   ;              
                    7:      frame_p2jiegou   <=  28  -1   ;              
                    8:      frame_p2jiegou   <=  32  -1   ;              
                    9:      frame_p2jiegou   <=  36  -1   ;              
                    10:     frame_p2jiegou   <=  40  -1   ;              
                    11:     frame_p2jiegou   <=  44  -1   ;              
                    12:     frame_p2jiegou   <=  48  -1   ;              
                    13:     frame_p2jiegou   <=  52  -1   ;              
                    14:     frame_p2jiegou   <=  56  -1   ;              
                    15:     frame_p2jiegou   <=  60  -1   ;              
                    16:     frame_p2jiegou   <=  64  -1   ;              
                    17:     frame_p2jiegou   <=  68  -1   ;              
                    18:     frame_p2jiegou   <=  72  -1   ;              
                    19:     frame_p2jiegou   <=  76  -1   ;              
                    20:     frame_p2jiegou   <=  80  -1   ;              
                    21:     frame_p2jiegou   <=  84  -1   ;              
                    22:     frame_p2jiegou   <=  88  -1   ;              
                    23:     frame_p2jiegou   <=  92  -1   ;              
                    24:     frame_p2jiegou   <=  96  -1   ;              
                    25:     frame_p2jiegou   <=  100 -1   ;              
                    26:     frame_p2jiegou   <=  104 -1 ;               
                    27:     frame_p2jiegou   <=  108 -1 ;               
                    28:     frame_p2jiegou   <=  112 -1 ;               
                    29:     frame_p2jiegou   <=  116 -1 ;               
                    30:     frame_p2jiegou   <=  120 -1 ;               
                    31:     frame_p2jiegou   <=  124 -1 ;               
                    32:     frame_p2jiegou   <=  128 -1 ;               
                    33:     frame_p2jiegou   <=  132 -1 ;               
                    34:     frame_p2jiegou   <=  136 -1 ;               
                    35:     frame_p2jiegou   <=  140 -1 ;               
                    36:     frame_p2jiegou   <=  144 -1 ;               
                    37:     frame_p2jiegou   <=  148 -1 ;               
                    38:     frame_p2jiegou   <=  152 -1 ;               
                    39:     frame_p2jiegou   <=  156 -1 ;               
                    40:     frame_p2jiegou   <=  160 -1 ;               
                    41:     frame_p2jiegou   <=  164 -1 ;               
                    42:     frame_p2jiegou   <=  168 -1 ;               
                    43:     frame_p2jiegou   <=  172 -1 ;               
                    44:     frame_p2jiegou   <=  176 -1 ;               
                    45:     frame_p2jiegou   <=  180 -1 ;               
                    46:     frame_p2jiegou   <=  184 -1 ;               
                    47:     frame_p2jiegou   <=  188 -1 ;               
                    48:     frame_p2jiegou   <=  192 -1 ;               
                    49:     frame_p2jiegou   <=  196 -1 ;               
                    50:     frame_p2jiegou   <=  200 -1 ;               
                    51:     frame_p2jiegou   <=  204 -1 ;               
                    52:     frame_p2jiegou   <=  208 -1 ;               
                    53:     frame_p2jiegou   <=  212 -1 ;               
                    54:     frame_p2jiegou   <=  216 -1 ;               
                    55:     frame_p2jiegou   <=  220 -1 ;               
                    56:     frame_p2jiegou   <=  224 -1 ;               
                    57:     frame_p2jiegou   <=  228 -1 ;               
                    58:     frame_p2jiegou   <=  232 -1 ;               
                    59:     frame_p2jiegou   <=  236 -1 ;               
                    60:     frame_p2jiegou   <=  240 -1 ;               
                    61:     frame_p2jiegou   <=  244 -1 ;               
                    62:     frame_p2jiegou   <=  248 -1 ;               
                    63:     frame_p2jiegou   <=  252 -1 ;               
                    64:     frame_p2jiegou   <=  256 -1 ;  
                endcase
            end
        end
      end
end


always@(posedge fifo7768_rdclk)begin
    if(!rstn)begin
        frame_p3jiegou   <=  0;
        end
    else if(state==FRAME_P3XOR)begin
        if({m_xcorr_dout_tvalid_pncode1check_r,m_xcorr_dout_tvalid_pncode1check}==2'b10)begin
            if(pncode1check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p3jiegou   <=  1   -1;
                    2:      frame_p3jiegou   <=  5   -1;
                    3:      frame_p3jiegou   <=  9   -1;
                    4:      frame_p3jiegou   <=  13  -1;
                    5:      frame_p3jiegou   <=  17  -1;              
                    6:      frame_p3jiegou   <=  21  -1;              
                    7:      frame_p3jiegou   <=  25  -1;              
                    8:      frame_p3jiegou   <=  29  -1;              
                    9:      frame_p3jiegou   <=  33  -1;              
                    10:     frame_p3jiegou   <=  37  -1;              
                    11:     frame_p3jiegou   <=  41  -1;              
                    12:     frame_p3jiegou   <=  45  -1;              
                    13:     frame_p3jiegou   <=  49  -1;              
                    14:     frame_p3jiegou   <=  53  -1;              
                    15:     frame_p3jiegou   <=  57  -1;              
                    16:     frame_p3jiegou   <=  61  -1;              
                    17:     frame_p3jiegou   <=  65  -1;              
                    18:     frame_p3jiegou   <=  69  -1;              
                    19:     frame_p3jiegou   <=  73  -1;              
                    20:     frame_p3jiegou   <=  77  -1;              
                    21:     frame_p3jiegou   <=  81  -1;              
                    22:     frame_p3jiegou   <=  85  -1;              
                    23:     frame_p3jiegou   <=  89  -1;              
                    24:     frame_p3jiegou   <=  93  -1;              
                    25:     frame_p3jiegou   <=  97  -1;              
                    26:     frame_p3jiegou   <=  101 -1;               
                    27:     frame_p3jiegou   <=  105 -1;               
                    28:     frame_p3jiegou   <=  109 -1;               
                    29:     frame_p3jiegou   <=  113 -1;               
                    30:     frame_p3jiegou   <=  117 -1;               
                    31:     frame_p3jiegou   <=  121 -1;               
                    32:     frame_p3jiegou   <=  125 -1;               
                    33:     frame_p3jiegou   <=  129 -1;               
                    34:     frame_p3jiegou   <=  133 -1;               
                    35:     frame_p3jiegou   <=  137 -1;               
                    36:     frame_p3jiegou   <=  141 -1;               
                    37:     frame_p3jiegou   <=  145 -1;               
                    38:     frame_p3jiegou   <=  149 -1;               
                    39:     frame_p3jiegou   <=  153 -1;               
                    40:     frame_p3jiegou   <=  157 -1;               
                    41:     frame_p3jiegou   <=  161 -1;               
                    42:     frame_p3jiegou   <=  165 -1;               
                    43:     frame_p3jiegou   <=  169 -1;               
                    44:     frame_p3jiegou   <=  173 -1;               
                    45:     frame_p3jiegou   <=  177 -1;               
                    46:     frame_p3jiegou   <=  181 -1;               
                    47:     frame_p3jiegou   <=  185 -1;               
                    48:     frame_p3jiegou   <=  189 -1;               
                    49:     frame_p3jiegou   <=  193 -1;               
                    50:     frame_p3jiegou   <=  197 -1;               
                    51:     frame_p3jiegou   <=  201 -1;               
                    52:     frame_p3jiegou   <=  205 -1;               
                    53:     frame_p3jiegou   <=  209 -1;               
                    54:     frame_p3jiegou   <=  213 -1;               
                    55:     frame_p3jiegou   <=  217 -1;               
                    56:     frame_p3jiegou   <=  221 -1;               
                    57:     frame_p3jiegou   <=  225 -1;               
                    58:     frame_p3jiegou   <=  229 -1;               
                    59:     frame_p3jiegou   <=  233 -1;               
                    60:     frame_p3jiegou   <=  237 -1;               
                    61:     frame_p3jiegou   <=  241 -1;               
                    62:     frame_p3jiegou   <=  245 -1;               
                    63:     frame_p3jiegou   <=  249 -1;               
                    64:     frame_p3jiegou   <=  253 -1;               
                    
               
                    
                endcase
            end
            
            else if(pncode2check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p3jiegou   <=  2  -1   ;
                    2:      frame_p3jiegou   <=  6  -1   ;
                    3:      frame_p3jiegou   <=  10 -1;
                    4:      frame_p3jiegou   <=  14 -1;
                    5:      frame_p3jiegou   <=  18 -1;              
                    6:      frame_p3jiegou   <=  22 -1;              
                    7:      frame_p3jiegou   <=  26 -1;              
                    8:      frame_p3jiegou   <=  30 -1;              
                    9:      frame_p3jiegou   <=  34 -1;              
                    10:     frame_p3jiegou   <=  38 -1;              
                    11:     frame_p3jiegou   <=  42 -1;              
                    12:     frame_p3jiegou   <=  46 -1;              
                    13:     frame_p3jiegou   <=  50 -1;              
                    14:     frame_p3jiegou   <=  54 -1;              
                    15:     frame_p3jiegou   <=  58 -1;              
                    16:     frame_p3jiegou   <=  62 -1;              
                    17:     frame_p3jiegou   <=  66 -1;              
                    18:     frame_p3jiegou   <=  70 -1;              
                    19:     frame_p3jiegou   <=  74 -1;              
                    20:     frame_p3jiegou   <=  78 -1;              
                    21:     frame_p3jiegou   <=  82 -1;              
                    22:     frame_p3jiegou   <=  86 -1;              
                    23:     frame_p3jiegou   <=  90 -1;              
                    24:     frame_p3jiegou   <=  94 -1;              
                    25:     frame_p3jiegou   <=  98 -1;              
                    26:     frame_p3jiegou   <=  102-1 ;               
                    27:     frame_p3jiegou   <=  106-1 ;               
                    28:     frame_p3jiegou   <=  110-1 ;               
                    29:     frame_p3jiegou   <=  114-1 ;               
                    30:     frame_p3jiegou   <=  118-1 ;               
                    31:     frame_p3jiegou   <=  122-1 ;               
                    32:     frame_p3jiegou   <=  126-1 ;               
                    33:     frame_p3jiegou   <=  130-1 ;               
                    34:     frame_p3jiegou   <=  134-1 ;               
                    35:     frame_p3jiegou   <=  138-1 ;               
                    36:     frame_p3jiegou   <=  142-1 ;               
                    37:     frame_p3jiegou   <=  146-1 ;               
                    38:     frame_p3jiegou   <=  150-1 ;               
                    39:     frame_p3jiegou   <=  154-1 ;               
                    40:     frame_p3jiegou   <=  158-1 ;               
                    41:     frame_p3jiegou   <=  162-1 ;               
                    42:     frame_p3jiegou   <=  166-1 ;               
                    43:     frame_p3jiegou   <=  170-1 ;               
                    44:     frame_p3jiegou   <=  174-1 ;               
                    45:     frame_p3jiegou   <=  178-1 ;               
                    46:     frame_p3jiegou   <=  182-1 ;               
                    47:     frame_p3jiegou   <=  186-1 ;               
                    48:     frame_p3jiegou   <=  190-1 ;               
                    49:     frame_p3jiegou   <=  194-1 ;               
                    50:     frame_p3jiegou   <=  198-1 ;               
                    51:     frame_p3jiegou   <=  202-1 ;               
                    52:     frame_p3jiegou   <=  206-1 ;               
                    53:     frame_p3jiegou   <=  210-1 ;               
                    54:     frame_p3jiegou   <=  214-1 ;               
                    55:     frame_p3jiegou   <=  218-1 ;               
                    56:     frame_p3jiegou   <=  222-1 ;               
                    57:     frame_p3jiegou   <=  226-1 ;               
                    58:     frame_p3jiegou   <=  230-1 ;               
                    59:     frame_p3jiegou   <=  234-1 ;               
                    60:     frame_p3jiegou   <=  238-1 ;               
                    61:     frame_p3jiegou   <=  242-1 ;               
                    62:     frame_p3jiegou   <=  246-1 ;               
                    63:     frame_p3jiegou   <=  250-1 ;               
                    64:     frame_p3jiegou   <=  254-1 ;   
                endcase
            end

        
            else if(pncode3check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p3jiegou   <=  3    -1  ;
                    2:      frame_p3jiegou   <=  7    -1  ;
                    3:      frame_p3jiegou   <=  11   -1  ;
                    4:      frame_p3jiegou   <=  15   -1  ;
                    5:      frame_p3jiegou   <=  19   -1  ;              
                    6:      frame_p3jiegou   <=  23   -1  ;              
                    7:      frame_p3jiegou   <=  27   -1  ;              
                    8:      frame_p3jiegou   <=  31   -1  ;              
                    9:      frame_p3jiegou   <=  35   -1  ;              
                    10:     frame_p3jiegou   <=  39   -1  ;              
                    11:     frame_p3jiegou   <=  43   -1  ;              
                    12:     frame_p3jiegou   <=  47   -1  ;              
                    13:     frame_p3jiegou   <=  51   -1  ;              
                    14:     frame_p3jiegou   <=  55   -1  ;              
                    15:     frame_p3jiegou   <=  59   -1  ;              
                    16:     frame_p3jiegou   <=  63   -1  ;              
                    17:     frame_p3jiegou   <=  67   -1  ;              
                    18:     frame_p3jiegou   <=  71   -1  ;              
                    19:     frame_p3jiegou   <=  75   -1  ;              
                    20:     frame_p3jiegou   <=  79   -1  ;              
                    21:     frame_p3jiegou   <=  83   -1  ;              
                    22:     frame_p3jiegou   <=  87   -1  ;              
                    23:     frame_p3jiegou   <=  91   -1  ;              
                    24:     frame_p3jiegou   <=  95   -1  ;              
                    25:     frame_p3jiegou   <=  99   -1  ;              
                    26:     frame_p3jiegou   <=  103  -1;               
                    27:     frame_p3jiegou   <=  107  -1;               
                    28:     frame_p3jiegou   <=  111  -1;               
                    29:     frame_p3jiegou   <=  115  -1;               
                    30:     frame_p3jiegou   <=  119  -1;               
                    31:     frame_p3jiegou   <=  123  -1;               
                    32:     frame_p3jiegou   <=  127  -1;               
                    33:     frame_p3jiegou   <=  131  -1;               
                    34:     frame_p3jiegou   <=  135  -1;               
                    35:     frame_p3jiegou   <=  139  -1;               
                    36:     frame_p3jiegou   <=  143  -1;               
                    37:     frame_p3jiegou   <=  147  -1;               
                    38:     frame_p3jiegou   <=  151  -1;               
                    39:     frame_p3jiegou   <=  155  -1;               
                    40:     frame_p3jiegou   <=  159  -1;               
                    41:     frame_p3jiegou   <=  163  -1;               
                    42:     frame_p3jiegou   <=  167  -1;               
                    43:     frame_p3jiegou   <=  171  -1;               
                    44:     frame_p3jiegou   <=  175  -1;               
                    45:     frame_p3jiegou   <=  179  -1;               
                    46:     frame_p3jiegou   <=  183  -1;               
                    47:     frame_p3jiegou   <=  187  -1;               
                    48:     frame_p3jiegou   <=  191  -1;               
                    49:     frame_p3jiegou   <=  195  -1;               
                    50:     frame_p3jiegou   <=  199  -1;               
                    51:     frame_p3jiegou   <=  203  -1;               
                    52:     frame_p3jiegou   <=  207  -1;               
                    53:     frame_p3jiegou   <=  211  -1;               
                    54:     frame_p3jiegou   <=  215  -1;               
                    55:     frame_p3jiegou   <=  219  -1;               
                    56:     frame_p3jiegou   <=  223  -1;               
                    57:     frame_p3jiegou   <=  227  -1;               
                    58:     frame_p3jiegou   <=  231  -1;               
                    59:     frame_p3jiegou   <=  235  -1;               
                    60:     frame_p3jiegou   <=  239  -1;               
                    61:     frame_p3jiegou   <=  243  -1;               
                    62:     frame_p3jiegou   <=  247  -1;               
                    63:     frame_p3jiegou   <=  251  -1;               
                    64:     frame_p3jiegou   <=  255  -1;   
                endcase
            end

 
        
            else if(pncode4check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p3jiegou   <=  4    -1  ;
                    2:      frame_p3jiegou   <=  8    -1  ;
                    3:      frame_p3jiegou   <=  12   -1  ;
                    4:      frame_p3jiegou   <=  16   -1  ;
                    5:      frame_p3jiegou   <=  20   -1  ;              
                    6:      frame_p3jiegou   <=  24   -1  ;              
                    7:      frame_p3jiegou   <=  28   -1  ;              
                    8:      frame_p3jiegou   <=  32   -1  ;              
                    9:      frame_p3jiegou   <=  36   -1  ;              
                    10:     frame_p3jiegou   <=  40   -1  ;              
                    11:     frame_p3jiegou   <=  44   -1  ;              
                    12:     frame_p3jiegou   <=  48   -1  ;              
                    13:     frame_p3jiegou   <=  52   -1  ;              
                    14:     frame_p3jiegou   <=  56   -1  ;              
                    15:     frame_p3jiegou   <=  60   -1  ;              
                    16:     frame_p3jiegou   <=  64   -1  ;              
                    17:     frame_p3jiegou   <=  68   -1  ;              
                    18:     frame_p3jiegou   <=  72   -1  ;              
                    19:     frame_p3jiegou   <=  76   -1  ;              
                    20:     frame_p3jiegou   <=  80   -1  ;              
                    21:     frame_p3jiegou   <=  84   -1  ;              
                    22:     frame_p3jiegou   <=  88   -1  ;              
                    23:     frame_p3jiegou   <=  92   -1  ;              
                    24:     frame_p3jiegou   <=  96   -1  ;              
                    25:     frame_p3jiegou   <=  100  -1  ;              
                    26:     frame_p3jiegou   <=  104  -1;               
                    27:     frame_p3jiegou   <=  108  -1;               
                    28:     frame_p3jiegou   <=  112  -1;               
                    29:     frame_p3jiegou   <=  116  -1;               
                    30:     frame_p3jiegou   <=  120  -1;               
                    31:     frame_p3jiegou   <=  124  -1;               
                    32:     frame_p3jiegou   <=  128  -1;               
                    33:     frame_p3jiegou   <=  132  -1;               
                    34:     frame_p3jiegou   <=  136  -1;               
                    35:     frame_p3jiegou   <=  140  -1;               
                    36:     frame_p3jiegou   <=  144  -1;               
                    37:     frame_p3jiegou   <=  148  -1;               
                    38:     frame_p3jiegou   <=  152  -1;               
                    39:     frame_p3jiegou   <=  156  -1;               
                    40:     frame_p3jiegou   <=  160  -1;               
                    41:     frame_p3jiegou   <=  164  -1;               
                    42:     frame_p3jiegou   <=  168  -1;               
                    43:     frame_p3jiegou   <=  172  -1;               
                    44:     frame_p3jiegou   <=  176  -1;               
                    45:     frame_p3jiegou   <=  180  -1;               
                    46:     frame_p3jiegou   <=  184  -1;               
                    47:     frame_p3jiegou   <=  188  -1;               
                    48:     frame_p3jiegou   <=  192  -1;               
                    49:     frame_p3jiegou   <=  196  -1;               
                    50:     frame_p3jiegou   <=  200  -1;               
                    51:     frame_p3jiegou   <=  204  -1;               
                    52:     frame_p3jiegou   <=  208  -1;               
                    53:     frame_p3jiegou   <=  212  -1;               
                    54:     frame_p3jiegou   <=  216  -1;               
                    55:     frame_p3jiegou   <=  220  -1;               
                    56:     frame_p3jiegou   <=  224  -1;               
                    57:     frame_p3jiegou   <=  228  -1;               
                    58:     frame_p3jiegou   <=  232  -1;               
                    59:     frame_p3jiegou   <=  236  -1;               
                    60:     frame_p3jiegou   <=  240  -1;               
                    61:     frame_p3jiegou   <=  244  -1;               
                    62:     frame_p3jiegou   <=  248  -1;               
                    63:     frame_p3jiegou   <=  252  -1;               
                    64:     frame_p3jiegou   <=  256  -1;  
                endcase
            end
        end
      end
end




always@(posedge fifo7768_rdclk)begin
    if(!rstn)begin
        frame_p4jiegou   <=  0;
        end
    else if(state==FRAME_P4XOR)begin
        if({m_xcorr_dout_tvalid_pncode1check_r,m_xcorr_dout_tvalid_pncode1check}==2'b10)begin
            if(pncode1check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p4jiegou   <=  1   -1 ;
                    2:      frame_p4jiegou   <=  5   -1 ;
                    3:      frame_p4jiegou   <=  9   -1 ;
                    4:      frame_p4jiegou   <=  13  -1 ;
                    5:      frame_p4jiegou   <=  17  -1 ;              
                    6:      frame_p4jiegou   <=  21  -1 ;              
                    7:      frame_p4jiegou   <=  25  -1 ;              
                    8:      frame_p4jiegou   <=  29  -1 ;              
                    9:      frame_p4jiegou   <=  33  -1 ;              
                    10:     frame_p4jiegou   <=  37  -1 ;              
                    11:     frame_p4jiegou   <=  41  -1 ;              
                    12:     frame_p4jiegou   <=  45  -1 ;              
                    13:     frame_p4jiegou   <=  49  -1 ;              
                    14:     frame_p4jiegou   <=  53  -1 ;              
                    15:     frame_p4jiegou   <=  57  -1 ;              
                    16:     frame_p4jiegou   <=  61  -1 ;              
                    17:     frame_p4jiegou   <=  65  -1 ;              
                    18:     frame_p4jiegou   <=  69  -1 ;              
                    19:     frame_p4jiegou   <=  73  -1 ;              
                    20:     frame_p4jiegou   <=  77  -1 ;              
                    21:     frame_p4jiegou   <=  81  -1 ;              
                    22:     frame_p4jiegou   <=  85  -1 ;              
                    23:     frame_p4jiegou   <=  89  -1 ;              
                    24:     frame_p4jiegou   <=  93  -1 ;              
                    25:     frame_p4jiegou   <=  97  -1 ;              
                    26:     frame_p4jiegou   <=  101 -1 ;               
                    27:     frame_p4jiegou   <=  105 -1 ;               
                    28:     frame_p4jiegou   <=  109 -1 ;               
                    29:     frame_p4jiegou   <=  113 -1 ;               
                    30:     frame_p4jiegou   <=  117 -1 ;               
                    31:     frame_p4jiegou   <=  121 -1 ;               
                    32:     frame_p4jiegou   <=  125 -1 ;               
                    33:     frame_p4jiegou   <=  129 -1 ;               
                    34:     frame_p4jiegou   <=  133 -1 ;               
                    35:     frame_p4jiegou   <=  137 -1 ;               
                    36:     frame_p4jiegou   <=  141 -1 ;               
                    37:     frame_p4jiegou   <=  145 -1 ;               
                    38:     frame_p4jiegou   <=  149 -1 ;               
                    39:     frame_p4jiegou   <=  153 -1 ;               
                    40:     frame_p4jiegou   <=  157 -1 ;               
                    41:     frame_p4jiegou   <=  161 -1 ;               
                    42:     frame_p4jiegou   <=  165 -1 ;               
                    43:     frame_p4jiegou   <=  169 -1 ;               
                    44:     frame_p4jiegou   <=  173 -1 ;               
                    45:     frame_p4jiegou   <=  177 -1 ;               
                    46:     frame_p4jiegou   <=  181 -1 ;               
                    47:     frame_p4jiegou   <=  185 -1 ;               
                    48:     frame_p4jiegou   <=  189 -1 ;               
                    49:     frame_p4jiegou   <=  193 -1 ;               
                    50:     frame_p4jiegou   <=  197 -1 ;               
                    51:     frame_p4jiegou   <=  201 -1 ;               
                    52:     frame_p4jiegou   <=  205 -1 ;               
                    53:     frame_p4jiegou   <=  209 -1 ;               
                    54:     frame_p4jiegou   <=  213 -1 ;               
                    55:     frame_p4jiegou   <=  217 -1 ;               
                    56:     frame_p4jiegou   <=  221 -1 ;               
                    57:     frame_p4jiegou   <=  225 -1 ;               
                    58:     frame_p4jiegou   <=  229 -1 ;               
                    59:     frame_p4jiegou   <=  233 -1 ;               
                    60:     frame_p4jiegou   <=  237 -1 ;               
                    61:     frame_p4jiegou   <=  241 -1 ;               
                    62:     frame_p4jiegou   <=  245 -1 ;               
                    63:     frame_p4jiegou   <=  249 -1 ;               
                    64:     frame_p4jiegou   <=  253 -1 ;               
                    
               
                    
                endcase
            end
            
            else if(pncode2check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p4jiegou   <=  2    -1  ;
                    2:      frame_p4jiegou   <=  6    -1  ;
                    3:      frame_p4jiegou   <=  10   -1   ;
                    4:      frame_p4jiegou   <=  14   -1   ;
                    5:      frame_p4jiegou   <=  18   -1   ;              
                    6:      frame_p4jiegou   <=  22   -1   ;              
                    7:      frame_p4jiegou   <=  26   -1   ;              
                    8:      frame_p4jiegou   <=  30   -1   ;              
                    9:      frame_p4jiegou   <=  34   -1   ;              
                    10:     frame_p4jiegou   <=  38   -1   ;              
                    11:     frame_p4jiegou   <=  42   -1   ;              
                    12:     frame_p4jiegou   <=  46   -1   ;              
                    13:     frame_p4jiegou   <=  50   -1   ;              
                    14:     frame_p4jiegou   <=  54   -1   ;              
                    15:     frame_p4jiegou   <=  58   -1   ;              
                    16:     frame_p4jiegou   <=  62   -1   ;              
                    17:     frame_p4jiegou   <=  66   -1   ;              
                    18:     frame_p4jiegou   <=  70   -1   ;              
                    19:     frame_p4jiegou   <=  74   -1   ;              
                    20:     frame_p4jiegou   <=  78   -1   ;              
                    21:     frame_p4jiegou   <=  82   -1   ;              
                    22:     frame_p4jiegou   <=  86   -1   ;              
                    23:     frame_p4jiegou   <=  90   -1   ;              
                    24:     frame_p4jiegou   <=  94   -1   ;              
                    25:     frame_p4jiegou   <=  98   -1   ;              
                    26:     frame_p4jiegou   <=  102  -1;               
                    27:     frame_p4jiegou   <=  106  -1;               
                    28:     frame_p4jiegou   <=  110  -1;               
                    29:     frame_p4jiegou   <=  114  -1;               
                    30:     frame_p4jiegou   <=  118  -1;               
                    31:     frame_p4jiegou   <=  122  -1;               
                    32:     frame_p4jiegou   <=  126  -1;               
                    33:     frame_p4jiegou   <=  130  -1;               
                    34:     frame_p4jiegou   <=  134  -1;               
                    35:     frame_p4jiegou   <=  138  -1;               
                    36:     frame_p4jiegou   <=  142  -1;               
                    37:     frame_p4jiegou   <=  146  -1;               
                    38:     frame_p4jiegou   <=  150  -1;               
                    39:     frame_p4jiegou   <=  154  -1;               
                    40:     frame_p4jiegou   <=  158  -1;               
                    41:     frame_p4jiegou   <=  162  -1;               
                    42:     frame_p4jiegou   <=  166  -1;               
                    43:     frame_p4jiegou   <=  170  -1;               
                    44:     frame_p4jiegou   <=  174  -1;               
                    45:     frame_p4jiegou   <=  178  -1;               
                    46:     frame_p4jiegou   <=  182  -1;               
                    47:     frame_p4jiegou   <=  186  -1;               
                    48:     frame_p4jiegou   <=  190  -1;               
                    49:     frame_p4jiegou   <=  194  -1;               
                    50:     frame_p4jiegou   <=  198  -1;               
                    51:     frame_p4jiegou   <=  202  -1;               
                    52:     frame_p4jiegou   <=  206  -1;               
                    53:     frame_p4jiegou   <=  210  -1;               
                    54:     frame_p4jiegou   <=  214  -1;               
                    55:     frame_p4jiegou   <=  218  -1;               
                    56:     frame_p4jiegou   <=  222  -1;               
                    57:     frame_p4jiegou   <=  226  -1;               
                    58:     frame_p4jiegou   <=  230  -1;               
                    59:     frame_p4jiegou   <=  234  -1;               
                    60:     frame_p4jiegou   <=  238  -1;               
                    61:     frame_p4jiegou   <=  242  -1;               
                    62:     frame_p4jiegou   <=  246  -1;               
                    63:     frame_p4jiegou   <=  250  -1;               
                    64:     frame_p4jiegou   <=  254  -1;   
                endcase                               
            end                                       
                                                      
                                                      
            else if(pncode3check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)                           
                    1:      frame_p4jiegou   <=  3    -1;
                    2:      frame_p4jiegou   <=  7    -1;
                    3:      frame_p4jiegou   <=  11   -1; 
                    4:      frame_p4jiegou   <=  15   -1; 
                    5:      frame_p4jiegou   <=  19   -1;              
                    6:      frame_p4jiegou   <=  23   -1;              
                    7:      frame_p4jiegou   <=  27   -1;              
                    8:      frame_p4jiegou   <=  31   -1;              
                    9:      frame_p4jiegou   <=  35   -1;              
                    10:     frame_p4jiegou   <=  39   -1;              
                    11:     frame_p4jiegou   <=  43   -1;              
                    12:     frame_p4jiegou   <=  47   -1;              
                    13:     frame_p4jiegou   <=  51   -1;              
                    14:     frame_p4jiegou   <=  55   -1;              
                    15:     frame_p4jiegou   <=  59   -1;              
                    16:     frame_p4jiegou   <=  63   -1;              
                    17:     frame_p4jiegou   <=  67   -1;              
                    18:     frame_p4jiegou   <=  71   -1;              
                    19:     frame_p4jiegou   <=  75   -1;              
                    20:     frame_p4jiegou   <=  79   -1;              
                    21:     frame_p4jiegou   <=  83   -1;              
                    22:     frame_p4jiegou   <=  87   -1;              
                    23:     frame_p4jiegou   <=  91   -1;              
                    24:     frame_p4jiegou   <=  95   -1;              
                    25:     frame_p4jiegou   <=  99   -1;              
                    26:     frame_p4jiegou   <=  103  -1;               
                    27:     frame_p4jiegou   <=  107  -1;               
                    28:     frame_p4jiegou   <=  111  -1;               
                    29:     frame_p4jiegou   <=  115  -1;               
                    30:     frame_p4jiegou   <=  119  -1;               
                    31:     frame_p4jiegou   <=  123  -1;               
                    32:     frame_p4jiegou   <=  127  -1;               
                    33:     frame_p4jiegou   <=  131  -1;               
                    34:     frame_p4jiegou   <=  135  -1;               
                    35:     frame_p4jiegou   <=  139  -1;               
                    36:     frame_p4jiegou   <=  143  -1;               
                    37:     frame_p4jiegou   <=  147  -1;               
                    38:     frame_p4jiegou   <=  151  -1;               
                    39:     frame_p4jiegou   <=  155  -1;               
                    40:     frame_p4jiegou   <=  159  -1;               
                    41:     frame_p4jiegou   <=  163  -1;               
                    42:     frame_p4jiegou   <=  167  -1;               
                    43:     frame_p4jiegou   <=  171  -1;               
                    44:     frame_p4jiegou   <=  175  -1;               
                    45:     frame_p4jiegou   <=  179  -1;               
                    46:     frame_p4jiegou   <=  183  -1;               
                    47:     frame_p4jiegou   <=  187  -1;               
                    48:     frame_p4jiegou   <=  191  -1;               
                    49:     frame_p4jiegou   <=  195  -1;               
                    50:     frame_p4jiegou   <=  199  -1;               
                    51:     frame_p4jiegou   <=  203  -1;               
                    52:     frame_p4jiegou   <=  207  -1;               
                    53:     frame_p4jiegou   <=  211  -1;               
                    54:     frame_p4jiegou   <=  215  -1;               
                    55:     frame_p4jiegou   <=  219  -1;               
                    56:     frame_p4jiegou   <=  223  -1;               
                    57:     frame_p4jiegou   <=  227  -1;               
                    58:     frame_p4jiegou   <=  231  -1;               
                    59:     frame_p4jiegou   <=  235  -1;               
                    60:     frame_p4jiegou   <=  239  -1;               
                    61:     frame_p4jiegou   <=  243  -1;               
                    62:     frame_p4jiegou   <=  247  -1;               
                    63:     frame_p4jiegou   <=  251  -1;               
                    64:     frame_p4jiegou   <=  255  -1;   
                endcase
            end

 
        
            else if(pncode4check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p4jiegou   <=  4    -1  ;
                    2:      frame_p4jiegou   <=  8    -1  ;
                    3:      frame_p4jiegou   <=  12   -1  ;
                    4:      frame_p4jiegou   <=  16   -1  ;
                    5:      frame_p4jiegou   <=  20   -1  ;              
                    6:      frame_p4jiegou   <=  24   -1  ;              
                    7:      frame_p4jiegou   <=  28   -1  ;              
                    8:      frame_p4jiegou   <=  32   -1  ;              
                    9:      frame_p4jiegou   <=  36   -1  ;              
                    10:     frame_p4jiegou   <=  40   -1  ;              
                    11:     frame_p4jiegou   <=  44   -1  ;              
                    12:     frame_p4jiegou   <=  48   -1  ;              
                    13:     frame_p4jiegou   <=  52   -1  ;              
                    14:     frame_p4jiegou   <=  56   -1  ;              
                    15:     frame_p4jiegou   <=  60   -1  ;              
                    16:     frame_p4jiegou   <=  64   -1  ;              
                    17:     frame_p4jiegou   <=  68   -1  ;              
                    18:     frame_p4jiegou   <=  72   -1  ;              
                    19:     frame_p4jiegou   <=  76   -1  ;              
                    20:     frame_p4jiegou   <=  80   -1  ;              
                    21:     frame_p4jiegou   <=  84   -1  ;              
                    22:     frame_p4jiegou   <=  88   -1  ;              
                    23:     frame_p4jiegou   <=  92   -1  ;              
                    24:     frame_p4jiegou   <=  96   -1  ;              
                    25:     frame_p4jiegou   <=  100  -1  ;              
                    26:     frame_p4jiegou   <=  104  -1;               
                    27:     frame_p4jiegou   <=  108  -1;               
                    28:     frame_p4jiegou   <=  112  -1;               
                    29:     frame_p4jiegou   <=  116  -1;               
                    30:     frame_p4jiegou   <=  120  -1;               
                    31:     frame_p4jiegou   <=  124  -1;               
                    32:     frame_p4jiegou   <=  128  -1;               
                    33:     frame_p4jiegou   <=  132  -1;               
                    34:     frame_p4jiegou   <=  136  -1;               
                    35:     frame_p4jiegou   <=  140  -1;               
                    36:     frame_p4jiegou   <=  144  -1;               
                    37:     frame_p4jiegou   <=  148  -1;               
                    38:     frame_p4jiegou   <=  152  -1;               
                    39:     frame_p4jiegou   <=  156  -1;               
                    40:     frame_p4jiegou   <=  160  -1;               
                    41:     frame_p4jiegou   <=  164  -1;               
                    42:     frame_p4jiegou   <=  168  -1;               
                    43:     frame_p4jiegou   <=  172  -1;               
                    44:     frame_p4jiegou   <=  176  -1;               
                    45:     frame_p4jiegou   <=  180  -1;               
                    46:     frame_p4jiegou   <=  184  -1;               
                    47:     frame_p4jiegou   <=  188  -1;               
                    48:     frame_p4jiegou   <=  192  -1;               
                    49:     frame_p4jiegou   <=  196  -1;               
                    50:     frame_p4jiegou   <=  200  -1;               
                    51:     frame_p4jiegou   <=  204  -1;               
                    52:     frame_p4jiegou   <=  208  -1;               
                    53:     frame_p4jiegou   <=  212  -1;               
                    54:     frame_p4jiegou   <=  216  -1;               
                    55:     frame_p4jiegou   <=  220  -1;               
                    56:     frame_p4jiegou   <=  224  -1;               
                    57:     frame_p4jiegou   <=  228  -1;               
                    58:     frame_p4jiegou   <=  232  -1;               
                    59:     frame_p4jiegou   <=  236  -1;               
                    60:     frame_p4jiegou   <=  240  -1;               
                    61:     frame_p4jiegou   <=  244  -1;               
                    62:     frame_p4jiegou   <=  248  -1;               
                    63:     frame_p4jiegou   <=  252  -1;               
                    64:     frame_p4jiegou   <=  256  -1;  
                endcase
            end
        end
      end
end




always@(posedge fifo7768_rdclk)begin
    if(!rstn)begin
        frame_p5jiegou   <=  0;
        end
    else if(state==FRAME_P5XOR)begin
        if({m_xcorr_dout_tvalid_pncode1check_r,m_xcorr_dout_tvalid_pncode1check}==2'b10)begin
            if(pncode1check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p5jiegou   <=  1   -1 ;
                    2:      frame_p5jiegou   <=  5   -1 ;
                    3:      frame_p5jiegou   <=  9   -1 ;
                    4:      frame_p5jiegou   <=  13  -1 ;
                    5:      frame_p5jiegou   <=  17  -1 ;              
                    6:      frame_p5jiegou   <=  21  -1 ;              
                    7:      frame_p5jiegou   <=  25  -1 ;              
                    8:      frame_p5jiegou   <=  29  -1 ;              
                    9:      frame_p5jiegou   <=  33  -1 ;              
                    10:     frame_p5jiegou   <=  37  -1 ;              
                    11:     frame_p5jiegou   <=  41  -1 ;              
                    12:     frame_p5jiegou   <=  45  -1 ;              
                    13:     frame_p5jiegou   <=  49  -1 ;              
                    14:     frame_p5jiegou   <=  53  -1 ;              
                    15:     frame_p5jiegou   <=  57  -1 ;              
                    16:     frame_p5jiegou   <=  61  -1 ;              
                    17:     frame_p5jiegou   <=  65  -1 ;              
                    18:     frame_p5jiegou   <=  69  -1 ;              
                    19:     frame_p5jiegou   <=  73  -1 ;              
                    20:     frame_p5jiegou   <=  77  -1 ;              
                    21:     frame_p5jiegou   <=  81  -1 ;              
                    22:     frame_p5jiegou   <=  85  -1 ;              
                    23:     frame_p5jiegou   <=  89  -1 ;              
                    24:     frame_p5jiegou   <=  93  -1 ;              
                    25:     frame_p5jiegou   <=  97  -1 ;              
                    26:     frame_p5jiegou   <=  101 -1 ;               
                    27:     frame_p5jiegou   <=  105 -1 ;               
                    28:     frame_p5jiegou   <=  109 -1 ;               
                    29:     frame_p5jiegou   <=  113 -1 ;               
                    30:     frame_p5jiegou   <=  117 -1 ;               
                    31:     frame_p5jiegou   <=  121 -1 ;               
                    32:     frame_p5jiegou   <=  125 -1 ;               
                    33:     frame_p5jiegou   <=  129 -1 ;               
                    34:     frame_p5jiegou   <=  133 -1 ;               
                    35:     frame_p5jiegou   <=  137 -1 ;               
                    36:     frame_p5jiegou   <=  141 -1 ;               
                    37:     frame_p5jiegou   <=  145 -1 ;               
                    38:     frame_p5jiegou   <=  149 -1 ;               
                    39:     frame_p5jiegou   <=  153 -1 ;               
                    40:     frame_p5jiegou   <=  157 -1 ;               
                    41:     frame_p5jiegou   <=  161 -1 ;               
                    42:     frame_p5jiegou   <=  165 -1 ;               
                    43:     frame_p5jiegou   <=  169 -1 ;               
                    44:     frame_p5jiegou   <=  173 -1 ;               
                    45:     frame_p5jiegou   <=  177 -1 ;               
                    46:     frame_p5jiegou   <=  181 -1 ;               
                    47:     frame_p5jiegou   <=  185 -1 ;               
                    48:     frame_p5jiegou   <=  189 -1 ;               
                    49:     frame_p5jiegou   <=  193 -1 ;               
                    50:     frame_p5jiegou   <=  197 -1 ;               
                    51:     frame_p5jiegou   <=  201 -1 ;               
                    52:     frame_p5jiegou   <=  205 -1 ;               
                    53:     frame_p5jiegou   <=  209 -1 ;               
                    54:     frame_p5jiegou   <=  213 -1 ;               
                    55:     frame_p5jiegou   <=  217 -1 ;               
                    56:     frame_p5jiegou   <=  221 -1 ;               
                    57:     frame_p5jiegou   <=  225 -1 ;               
                    58:     frame_p5jiegou   <=  229 -1 ;               
                    59:     frame_p5jiegou   <=  233 -1 ;               
                    60:     frame_p5jiegou   <=  237 -1 ;               
                    61:     frame_p5jiegou   <=  241 -1 ;               
                    62:     frame_p5jiegou   <=  245 -1 ;               
                    63:     frame_p5jiegou   <=  249 -1 ;               
                    64:     frame_p5jiegou   <=  253 -1 ;               
                    
               
                    
                endcase
            end
            
            else if(pncode2check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p5jiegou   <=  2   -1   ;
                    2:      frame_p5jiegou   <=  6   -1   ;
                    3:      frame_p5jiegou   <=  10  -1;
                    4:      frame_p5jiegou   <=  14  -1;
                    5:      frame_p5jiegou   <=  18  -1;              
                    6:      frame_p5jiegou   <=  22  -1;              
                    7:      frame_p5jiegou   <=  26  -1;              
                    8:      frame_p5jiegou   <=  30  -1;              
                    9:      frame_p5jiegou   <=  34  -1;              
                    10:     frame_p5jiegou   <=  38  -1;              
                    11:     frame_p5jiegou   <=  42  -1;              
                    12:     frame_p5jiegou   <=  46  -1;              
                    13:     frame_p5jiegou   <=  50  -1;              
                    14:     frame_p5jiegou   <=  54  -1;              
                    15:     frame_p5jiegou   <=  58  -1;              
                    16:     frame_p5jiegou   <=  62  -1;              
                    17:     frame_p5jiegou   <=  66  -1;              
                    18:     frame_p5jiegou   <=  70  -1;              
                    19:     frame_p5jiegou   <=  74  -1;              
                    20:     frame_p5jiegou   <=  78  -1;              
                    21:     frame_p5jiegou   <=  82  -1;              
                    22:     frame_p5jiegou   <=  86  -1;              
                    23:     frame_p5jiegou   <=  90  -1;              
                    24:     frame_p5jiegou   <=  94  -1;              
                    25:     frame_p5jiegou   <=  98  -1;              
                    26:     frame_p5jiegou   <=  102 -1 ;               
                    27:     frame_p5jiegou   <=  106 -1 ;               
                    28:     frame_p5jiegou   <=  110 -1 ;               
                    29:     frame_p5jiegou   <=  114 -1 ;               
                    30:     frame_p5jiegou   <=  118 -1 ;               
                    31:     frame_p5jiegou   <=  122 -1 ;               
                    32:     frame_p5jiegou   <=  126 -1 ;               
                    33:     frame_p5jiegou   <=  130 -1 ;               
                    34:     frame_p5jiegou   <=  134 -1 ;               
                    35:     frame_p5jiegou   <=  138 -1 ;               
                    36:     frame_p5jiegou   <=  142 -1 ;               
                    37:     frame_p5jiegou   <=  146 -1 ;               
                    38:     frame_p5jiegou   <=  150 -1 ;               
                    39:     frame_p5jiegou   <=  154 -1 ;               
                    40:     frame_p5jiegou   <=  158 -1 ;               
                    41:     frame_p5jiegou   <=  162 -1 ;               
                    42:     frame_p5jiegou   <=  166 -1 ;               
                    43:     frame_p5jiegou   <=  170 -1 ;               
                    44:     frame_p5jiegou   <=  174 -1 ;               
                    45:     frame_p5jiegou   <=  178 -1 ;               
                    46:     frame_p5jiegou   <=  182 -1 ;               
                    47:     frame_p5jiegou   <=  186 -1 ;               
                    48:     frame_p5jiegou   <=  190 -1 ;               
                    49:     frame_p5jiegou   <=  194 -1 ;               
                    50:     frame_p5jiegou   <=  198 -1 ;               
                    51:     frame_p5jiegou   <=  202 -1 ;               
                    52:     frame_p5jiegou   <=  206 -1 ;               
                    53:     frame_p5jiegou   <=  210 -1 ;               
                    54:     frame_p5jiegou   <=  214 -1 ;               
                    55:     frame_p5jiegou   <=  218 -1 ;               
                    56:     frame_p5jiegou   <=  222 -1 ;               
                    57:     frame_p5jiegou   <=  226 -1 ;               
                    58:     frame_p5jiegou   <=  230 -1 ;               
                    59:     frame_p5jiegou   <=  234 -1 ;               
                    60:     frame_p5jiegou   <=  238 -1 ;               
                    61:     frame_p5jiegou   <=  242 -1 ;               
                    62:     frame_p5jiegou   <=  246 -1 ;               
                    63:     frame_p5jiegou   <=  250 -1 ;               
                    64:     frame_p5jiegou   <=  254 -1 ;   
                endcase
            end

        
            else if(pncode3check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p5jiegou   <=  3    -1  ;
                    2:      frame_p5jiegou   <=  7    -1  ;
                    3:      frame_p5jiegou   <=  11   -1  ;
                    4:      frame_p5jiegou   <=  15   -1  ;
                    5:      frame_p5jiegou   <=  19   -1  ;              
                    6:      frame_p5jiegou   <=  23   -1  ;              
                    7:      frame_p5jiegou   <=  27   -1  ;              
                    8:      frame_p5jiegou   <=  31   -1  ;              
                    9:      frame_p5jiegou   <=  35   -1  ;              
                    10:     frame_p5jiegou   <=  39   -1  ;              
                    11:     frame_p5jiegou   <=  43   -1  ;              
                    12:     frame_p5jiegou   <=  47   -1  ;              
                    13:     frame_p5jiegou   <=  51   -1  ;              
                    14:     frame_p5jiegou   <=  55   -1  ;              
                    15:     frame_p5jiegou   <=  59   -1  ;              
                    16:     frame_p5jiegou   <=  63   -1  ;              
                    17:     frame_p5jiegou   <=  67   -1  ;              
                    18:     frame_p5jiegou   <=  71   -1  ;              
                    19:     frame_p5jiegou   <=  75   -1  ;              
                    20:     frame_p5jiegou   <=  79   -1  ;              
                    21:     frame_p5jiegou   <=  83   -1  ;              
                    22:     frame_p5jiegou   <=  87   -1  ;              
                    23:     frame_p5jiegou   <=  91   -1  ;              
                    24:     frame_p5jiegou   <=  95   -1  ;              
                    25:     frame_p5jiegou   <=  99   -1  ;              
                    26:     frame_p5jiegou   <=  103  -1  ;               
                    27:     frame_p5jiegou   <=  107  -1  ;               
                    28:     frame_p5jiegou   <=  111  -1  ;               
                    29:     frame_p5jiegou   <=  115  -1  ;               
                    30:     frame_p5jiegou   <=  119  -1  ;               
                    31:     frame_p5jiegou   <=  123  -1  ;               
                    32:     frame_p5jiegou   <=  127  -1  ;               
                    33:     frame_p5jiegou   <=  131  -1  ;               
                    34:     frame_p5jiegou   <=  135  -1  ;               
                    35:     frame_p5jiegou   <=  139  -1  ;               
                    36:     frame_p5jiegou   <=  143  -1  ;               
                    37:     frame_p5jiegou   <=  147  -1  ;               
                    38:     frame_p5jiegou   <=  151  -1  ;               
                    39:     frame_p5jiegou   <=  155  -1  ;               
                    40:     frame_p5jiegou   <=  159  -1  ;               
                    41:     frame_p5jiegou   <=  163  -1  ;               
                    42:     frame_p5jiegou   <=  167  -1  ;               
                    43:     frame_p5jiegou   <=  171  -1  ;               
                    44:     frame_p5jiegou   <=  175  -1  ;               
                    45:     frame_p5jiegou   <=  179  -1  ;               
                    46:     frame_p5jiegou   <=  183  -1  ;               
                    47:     frame_p5jiegou   <=  187  -1  ;               
                    48:     frame_p5jiegou   <=  191  -1  ;               
                    49:     frame_p5jiegou   <=  195  -1  ;               
                    50:     frame_p5jiegou   <=  199  -1  ;               
                    51:     frame_p5jiegou   <=  203  -1  ;               
                    52:     frame_p5jiegou   <=  207  -1  ;               
                    53:     frame_p5jiegou   <=  211  -1  ;               
                    54:     frame_p5jiegou   <=  215  -1  ;               
                    55:     frame_p5jiegou   <=  219  -1  ;               
                    56:     frame_p5jiegou   <=  223  -1  ;               
                    57:     frame_p5jiegou   <=  227  -1  ;               
                    58:     frame_p5jiegou   <=  231  -1  ;               
                    59:     frame_p5jiegou   <=  235  -1  ;               
                    60:     frame_p5jiegou   <=  239  -1  ;               
                    61:     frame_p5jiegou   <=  243  -1  ;               
                    62:     frame_p5jiegou   <=  247  -1  ;               
                    63:     frame_p5jiegou   <=  251  -1  ;               
                    64:     frame_p5jiegou   <=  255  -1  ;   
                endcase
            end

 
        
            else if(pncode4check_fraction_max>=Pn_XCOR_MAX)begin
                case(f_cnt)
                    1:      frame_p5jiegou   <=  4    -1  ;
                    2:      frame_p5jiegou   <=  8    -1  ;
                    3:      frame_p5jiegou   <=  12   -1  ;
                    4:      frame_p5jiegou   <=  16   -1  ;
                    5:      frame_p5jiegou   <=  20   -1  ;              
                    6:      frame_p5jiegou   <=  24   -1  ;              
                    7:      frame_p5jiegou   <=  28   -1  ;              
                    8:      frame_p5jiegou   <=  32   -1  ;              
                    9:      frame_p5jiegou   <=  36   -1  ;              
                    10:     frame_p5jiegou   <=  40   -1  ;              
                    11:     frame_p5jiegou   <=  44   -1  ;              
                    12:     frame_p5jiegou   <=  48   -1  ;              
                    13:     frame_p5jiegou   <=  52   -1  ;              
                    14:     frame_p5jiegou   <=  56   -1  ;              
                    15:     frame_p5jiegou   <=  60   -1  ;              
                    16:     frame_p5jiegou   <=  64   -1  ;              
                    17:     frame_p5jiegou   <=  68   -1  ;              
                    18:     frame_p5jiegou   <=  72   -1  ;              
                    19:     frame_p5jiegou   <=  76   -1  ;              
                    20:     frame_p5jiegou   <=  80   -1  ;              
                    21:     frame_p5jiegou   <=  84   -1  ;              
                    22:     frame_p5jiegou   <=  88   -1  ;              
                    23:     frame_p5jiegou   <=  92   -1  ;              
                    24:     frame_p5jiegou   <=  96   -1  ;              
                    25:     frame_p5jiegou   <=  100  -1  ;              
                    26:     frame_p5jiegou   <=  104  -1;               
                    27:     frame_p5jiegou   <=  108  -1;               
                    28:     frame_p5jiegou   <=  112  -1;               
                    29:     frame_p5jiegou   <=  116  -1;               
                    30:     frame_p5jiegou   <=  120  -1;               
                    31:     frame_p5jiegou   <=  124  -1;               
                    32:     frame_p5jiegou   <=  128  -1;               
                    33:     frame_p5jiegou   <=  132  -1;               
                    34:     frame_p5jiegou   <=  136  -1;               
                    35:     frame_p5jiegou   <=  140  -1;               
                    36:     frame_p5jiegou   <=  144  -1;               
                    37:     frame_p5jiegou   <=  148  -1;               
                    38:     frame_p5jiegou   <=  152  -1;               
                    39:     frame_p5jiegou   <=  156  -1;               
                    40:     frame_p5jiegou   <=  160  -1;               
                    41:     frame_p5jiegou   <=  164  -1;               
                    42:     frame_p5jiegou   <=  168  -1;               
                    43:     frame_p5jiegou   <=  172  -1;               
                    44:     frame_p5jiegou   <=  176  -1;               
                    45:     frame_p5jiegou   <=  180  -1;               
                    46:     frame_p5jiegou   <=  184  -1;               
                    47:     frame_p5jiegou   <=  188  -1;               
                    48:     frame_p5jiegou   <=  192  -1;               
                    49:     frame_p5jiegou   <=  196  -1;               
                    50:     frame_p5jiegou   <=  200  -1;               
                    51:     frame_p5jiegou   <=  204  -1;               
                    52:     frame_p5jiegou   <=  208  -1;               
                    53:     frame_p5jiegou   <=  212  -1;               
                    54:     frame_p5jiegou   <=  216  -1;               
                    55:     frame_p5jiegou   <=  220  -1;               
                    56:     frame_p5jiegou   <=  224  -1;               
                    57:     frame_p5jiegou   <=  228  -1;               
                    58:     frame_p5jiegou   <=  232  -1;               
                    59:     frame_p5jiegou   <=  236  -1;               
                    60:     frame_p5jiegou   <=  240  -1;               
                    61:     frame_p5jiegou   <=  244  -1;               
                    62:     frame_p5jiegou   <=  248  -1;               
                    63:     frame_p5jiegou   <=  252  -1;               
                    64:     frame_p5jiegou   <=  256  -1;  
                endcase
            end
        end
      end
end
/************* frame_code_jiegou end****************/

/************* 防呆防锁死 begin****************/
reg [31:0] cnt_antibs;

always@(posedge fifo7768_rdclk)begin
    if(!checkbegin_flag)begin
        cnt_antibs<=0;
        frame_noresult<=0;
    end    
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR)||(state==FRAME_P5XOR))
        if(cnt_antibs>=5000_000)begin
            frame_noresult<=1;
        end
        else 
            cnt_antibs<=cnt_antibs+1;
            

    end




/************* 防呆防锁死 end****************/

 
    
endmodule
