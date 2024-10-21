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
frame_code_jiegou


    );
    
input clk;
input [47:0]sin_yuzhi;
(* Mark_debug = "TRUE" *) input checkbegin_flag;
(* Mark_debug = "TRUE" *) input [23:0] fifo7768_data;    
input [10:0]   code1_xcor_yuzhi ;
input [10:0]   pn_xcor_yuzhi;
    
    
 output fifo7768_rdclk;
(* Mark_debug = "TRUE" *) output reg fifo7768_rden;
(* Mark_debug = "TRUE" *) output reg fifo7768_refresh;
output reg frame_check_end;
(* Mark_debug = "TRUE" *)output reg [11:0] frame_code_jiegou;

reg rstn=0;

always@(posedge fifo7768_rdclk)begin
        rstn    <=  checkbegin_flag;

end


parameter sqrt_Rss0_2_dimi65536 =   'd779075; 
parameter sqrt_R110_2_dimi65536 =   'd541886;
parameter sqrt_R220_2_dimi65536 =   'd523437;
parameter sqrt_R330_2_dimi65536 =   'd555036;
parameter sqrt_R440_2_dimi65536 =   'd524619;

parameter IDLE = 'd0;
parameter FRAME_SINCHECK0 = 'd1;
parameter FRAME_SINCHECK1 = 'd2;
parameter FRAME_SINXOR    = 'd3;
parameter FRAME_CODE1CHECK0 = 'd4;
parameter FRAME_CODE1CHECK1 = 'd16;
parameter DELAY1 = 'd5;
parameter FRAME_CODE_DELAY   = 'd6;
parameter FRAME_CODE1DELAY  =   'd7;
parameter FRAME_CODE1XOR    =   'd8;
parameter FRAME_P2CHECK   =   'd9;
parameter FRAME_P2XOR     =   'd10;
parameter FRAME_P3CHECK  =   'd11;
parameter FRAME_P3XOR       =   'd12;
parameter FRAME_P4CHECK     =   'd13;
parameter FRAME_P4XOR       =   'd14;
parameter FRAME_END         =   'd15;

(* Mark_debug = "TRUE" *) reg [15:0] rd_data_cnt;
(* Mark_debug = "TRUE" *) reg [15:0] cnt_15240=0;


(* Mark_debug = "TRUE" *) reg [4:0] state;

reg [3:0] cnt_rstn;

reg sin_10khz_h = 0;

(* Mark_debug = "TRUE" *)reg frame_sin10khz_cfm=0;
reg frame_sin_ncfm=0;
(* Mark_debug = "TRUE" *)reg frame_code1_cfm=0; 
reg frame_code1_ncfm=0;
reg frame_p2code1_cfm=0;
reg frame_p2code2_cfm=0;
reg frame_p2code3_cfm=0;
reg frame_p2code4_cfm=0;

reg frame_p3code1_cfm=0;
reg frame_p3code2_cfm=0;
reg frame_p3code3_cfm=0;
reg frame_p3code4_cfm=0;

reg frame_p4code1_cfm=0;
reg frame_p4code2_cfm=0;
reg frame_p4code3_cfm=0;
reg frame_p4code4_cfm=0;

//定义数据参数

// MAXMAX: 9532724480000
wire [47:0]SIN_MAX;
wire [10:0] CODE1_XCOR_MAX;
wire [10:0] Pn_XCOR_MAX;
assign SIN_MAX   =   sin_yuzhi;            //确定粗同步帧头的触发阈值
assign CODE1_XCOR_MAX = code1_xcor_yuzhi;  //细同步帧头的相关函数阈值
assign Pn_XCOR_MAX = pn_xcor_yuzhi;        //其它位置码元段的相关函数阈值
    
parameter FIFO7768_FRAMEHALF_MAX = 'd15240;
parameter RD_DATA_CNT_MAX = 'd2048;          //7768fifo 数据读出后 fft 变换长度
parameter CODE_DELAY_MAX = 'd1494;      //读取码元段间隔0 与某code左右 多读的长度有关
parameter ONECODE_XOR_FIFOLEN = 'd1544; //比码元段长度多20，多读20个数据，前后各10个，确保包含code 码元 
parameter SINCHECK_HALF_MAX = 'd772;        // 粗同步帧头sin 检测时 读一半存一半 长度
parameter CODE1CHECK_HALFFIFO_MAX = 'd1524;  // 细同步帧头检测时，每次移动20个数据，则有这么多个数据存入fifo
parameter CODE1_CHECK_SHIFT_NUM = 'd20;      //细同步帧头 检测时，每次移动这么多个数据



assign fifo7768_rdclk   =   clk;

// 发送帧结构： sin——code1——P2——P3——P4  （ —— 代表间隔0）



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
                        state   <=  FRAME_CODE_DELAY;
                   end
                        
                   else
                        state   <=  state;
                end
                
                
            FRAME_SINCHECK1:begin                  //2
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_SINXOR;
                    else if(cnt_15240>=15241)
                        state   <=  IDLE;
                
                end
           FRAME_CODE_DELAY:begin                 //6 间隔1524点
                    if((rd_data_cnt==1494)&&(frame_sin10khz_cfm&&(!frame_code1_cfm)))
                        state   <=  FRAME_CODE1CHECK0; 
                    else if((rd_data_cnt==1494)&&(frame_sin10khz_cfm&&frame_code1_cfm&&(!(frame_p2code1_cfm||frame_p2code2_cfm||frame_p2code3_cfm||frame_p2code4_cfm))))
                        state   <=  FRAME_P2CHECK;
                    else if((rd_data_cnt==1494)&&(frame_sin10khz_cfm&&frame_code1_cfm&&(!(frame_p3code1_cfm||frame_p3code2_cfm||frame_p3code3_cfm||frame_p3code4_cfm))))
                        state   <=  FRAME_P3CHECK; 
                    else if((rd_data_cnt==1494)&&(frame_sin10khz_cfm&&frame_code1_cfm&&(!(frame_p4code1_cfm||frame_p4code2_cfm||frame_p4code3_cfm||frame_p4code4_cfm))))
                        state   <=  FRAME_P4CHECK;
                    else 
                        state   <=  state;           
                end
            
          FRAME_CODE1CHECK0:begin        //4
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_CODE1XOR;
                    else
                        state   <=  state;
                end
          
          
          FRAME_CODE1XOR:begin         //8
                    if(frame_code1_cfm)
                        state   <=  FRAME_CODE_DELAY;
                    else if(frame_code1_ncfm)
                        state   <=  FRAME_CODE1CHECK1;
                
                end
          
          FRAME_CODE1CHECK1:begin       //16
                    if(rd_data_cnt==2049)
                        state   <=  FRAME_CODE1XOR;
                    else if(cnt_15240>=16000)
                        state   <=  IDLE;
                end
          
          FRAME_P2CHECK: begin            //9
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_P2XOR;
                    else 
                        state   <=  state;
                end
         
          FRAME_P2XOR:begin             //  10 (a)
                    if((frame_p2code1_cfm)||(frame_p2code2_cfm)||(frame_p2code3_cfm)||(frame_p2code4_cfm))
                        state   <=  FRAME_CODE_DELAY;
                    else 
                        state   <=  state;
                end
             
          FRAME_P3CHECK:begin           //11
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_P3XOR;
                    else 
                        state   <=  state;
                end
                
          FRAME_P3XOR:begin            //12
                    if((frame_p3code1_cfm)||(frame_p3code2_cfm)||(frame_p3code3_cfm)||(frame_p3code4_cfm))
                        state   <=  FRAME_CODE_DELAY;
                    else 
                        state   <=  state;
                    
                end

          FRAME_P4CHECK:begin           //13
                    if(rd_data_cnt==2048)
                        state   <=  FRAME_P4XOR;
                    else 
                        state   <=  state;
                end
                
          FRAME_P4XOR:begin             //14
                    if((frame_p4code1_cfm)||(frame_p4code2_cfm)||(frame_p4code3_cfm)||(frame_p4code4_cfm))
                        state   <=  FRAME_END;
                    else 
                        state   <=  state;
                    
                end
        
        FRAME_END:begin             //15
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
        frame_code_jiegou <=  {frame_p2code1_cfm,frame_p2code2_cfm,frame_p2code3_cfm,frame_p2code4_cfm,frame_p3code1_cfm,frame_p3code2_cfm,frame_p3code3_cfm,frame_p3code4_cfm,frame_p4code1_cfm,frame_p4code2_cfm,frame_p4code3_cfm,frame_p4code4_cfm};
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
    
    else if(state==FRAME_CODE_DELAY)begin  //读取7768fifo 中的码元段间隔0
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
    
    else if(state==FRAME_P3CHECK)begin
        if(0 <= rd_data_cnt && rd_data_cnt <= 1543)
            fifo7768_rden   <=  1;
        else 
            fifo7768_rden   <=  0;
    end
    
    else if(state==FRAME_P4CHECK)begin
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

    else if(state==FRAME_CODE_DELAY)begin
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
    
    else if((state==FRAME_P2CHECK)||(state==FRAME_P3CHECK)||(state==FRAME_P4CHECK))begin
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

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_rstn    <=  0;
        
    else if(state_r!=state)
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
    
    else if((state==FRAME_CODE1XOR)||(state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(cnt_m_fft_frame_check_data>=600)begin //code1xor pnxor  截断数据有效信号的下降沿复位ip核
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
    else if(m_fft_frame_check_data_tvalid)
        cnt_m_fft_frame_check_data  <=  cnt_m_fft_frame_check_data +1;

end
     

 
 
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/    
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/  
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/  
/*************   进行帧头sin 的检测   FRAME_SINXOR 状态3 ************/  


(* Mark_debug = "TRUE" *)wire [23:0] m_fft_frame_check_data_re;
(* Mark_debug = "TRUE" *)wire [23:0] m_fft_frame_check_data_im;

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

 reg [47:0] fft_sin_abs2_max;
(* Mark_debug = "TRUE" *) reg [15:0] cnt_fft_sin_abs2_max;

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
        if(298<=cnt_m_fft_frame_check_data && cnt_m_fft_frame_check_data <= 553)
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

reg [10:0] ram_conjdata_addra_sin;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        ram_conjdata_addra_sin  <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_sin  <=  0;
    else if(frame_code_cut_valid)
        ram_conjdata_addra_sin  <=  ram_conjdata_addra_sin +1;
end

reg [10:0] ram_conjdata_addra_code;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_code <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_code <=  0;
    else case(state)
        FRAME_CODE1XOR: ram_conjdata_addra_code <=  ram_conjdata_addra_sin+256;
        default:ram_conjdata_addra_code <=  0;
    endcase
      


end

wire [47:0] fftconj_300555_data;


blk_mem_gen_0 fram_sin_check (
  .clka(fifo7768_rdclk),    // input wire clka
  .ena(frame_code_cut_valid),      // input wire ena
  .addra(ram_conjdata_addra_code),  // input wire [10 : 0] addra
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

(* Mark_debug = "TRUE" *)reg [10:0] code1check_fraction_max;

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





/*************    pncode1_check    begin    ************/    
/*************    pncode1_check    begin    ************/  
/*************    pncode1_check    begin    ************/  
/*************    pncode1_check    begin    ************/ 



reg frame_pncode2_cut_valid;
    
always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        frame_pncode2_cut_valid <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(298<=cnt_m_fft_frame_check_data && cnt_m_fft_frame_check_data <= 553)
            frame_pncode2_cut_valid <=  1;
    else
        frame_pncode2_cut_valid <=  0;
    
end

reg [10:0] ram_conjdata_addra;

always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        ram_conjdata_addra  <=  0;
    else if(state_r!=state)
        ram_conjdata_addra  <=  0;
    else if(frame_pncode2_cut_valid)
        ram_conjdata_addra  <=  ram_conjdata_addra +1;
end



reg [10:0] ram_conjdata_addra_pncode1check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode1check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode1check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode1check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+256;
        FRAME_P3XOR: ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+256;
        FRAME_P4XOR: ram_conjdata_addra_pncode1check    <=  ram_conjdata_addra+256;
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
  .s_axis_a_tdata(m_fft_frame_check_data),          // input wire [47 : 0] s_axis_a_tdata
  
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode1check_r <=  m_ifft_Rxy_tvalid_pncode1check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode1check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode1check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode1check_r2 <=  m_ifft_Rxy_tvalid_pncode1check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode1check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode1check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode1check_r3 <=  m_ifft_Rxy_tvalid_pncode1check_r2;
end

reg [79:0]  Rxy_abs2_pncode1check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode1check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode1check_n0 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
  
  .s_axis_data_tdata(m_fft_frame_check_data),                      // input wire [47 : 0] s_axis_data_tdata
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxx0_tvalid_pncode1check)
            fft_sin_cut_abs2_pncode1check_multip <= fft_sin_cut_abs2_pncode1check_repart+fft_sin_cut_abs2_pncode1check_impart;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(fft_sin_cut_sum_abs2_pncode1check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode1check <=  fft_sin_cut_sum_abs2_pncode1check + fft_sin_cut_abs2_pncode1check_multip;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxy_tlast_pncode1check)
            flag_Rxy_abs2_pncode1check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode1check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode1check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode1check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode1check_d <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if({fft_sin_cut_sum_abs2_pncode1check_tvalid_r,fft_sin_cut_sum_abs2_pncode1check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode1check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode1check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode1check  <=  0;
    else if(state_r!=state)
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
//            FRAME_CODE1XOR: s_xcorr_divisor_tdata_pncode1check   <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;  
            FRAME_P2XOR:    s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
            FRAME_P3XOR:    s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
            FRAME_P4XOR:    s_xcorr_divisor_tdata_pncode1check    <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode1check;
            default:s_xcorr_divisor_tdata_pncode1check   <=  0;
        endcase
        
end
    
(* Mark_debug = "TRUE" *)wire m_xcorr_dout_tvalid_pncode1check;
wire [79:0]m_xcorr_sin_dout_tdata_pncode1check;
wire [63:0] pncode1check_quotient;
(* Mark_debug = "TRUE" *)wire [10:0] pncode1check_fraction; 
reg m_xcorr_dout_tvalid_pncode1check_r;



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


always@(posedge fifo7768_rdclk or negedge rstn)begin //对m_xcorr_dout_tvalid_pncode1check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode1check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode1check_r    <=  m_xcorr_dout_tvalid_pncode1check;


end


(* Mark_debug = "TRUE" *)reg [10:0] pncode1check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode1check_fraction_max <=  0;
    else if(state_r!=state)
        pncode1check_fraction_max <=  0;    
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))begin
        if(m_xcorr_dout_tvalid_pncode1check && (pncode1check_fraction>pncode1check_fraction_max))
           pncode1check_fraction_max<=pncode1check_fraction;
    end

end


always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)begin
        frame_p2code1_cfm   <=  0;
        frame_p3code1_cfm   <=  0;
        frame_p4code1_cfm   <=  0;
        end
    else if(state==FRAME_P2XOR)begin
        if({m_xcorr_dout_tvalid_pncode1check_r,m_xcorr_dout_tvalid_pncode1check}==2'b10)begin
            if(pncode1check_fraction_max>=Pn_XCOR_MAX)
                frame_p2code1_cfm   <=  1;            
        end

   end
   
   else if(state==FRAME_P3XOR)begin
        if({m_xcorr_dout_tvalid_pncode1check_r,m_xcorr_dout_tvalid_pncode1check}==2'b10)begin
            if(pncode1check_fraction_max>=Pn_XCOR_MAX)
                frame_p3code1_cfm   <=  1;            
        end

   end 

   else if(state==FRAME_P4XOR)begin
        if({m_xcorr_dout_tvalid_pncode1check_r,m_xcorr_dout_tvalid_pncode1check}==2'b10)begin
            if(pncode1check_fraction_max>=Pn_XCOR_MAX)
                frame_p4code1_cfm   <=  1;            
        end

   end    
   
    else begin
         frame_p2code1_cfm  <=  frame_p2code1_cfm;
         frame_p3code1_cfm  <=  frame_p3code1_cfm;
         frame_p4code1_cfm  <=  frame_p4code1_cfm;
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




reg [10:0] ram_conjdata_addra_pncode2check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode2check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode2check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode2check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+512;
        FRAME_P3XOR: ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+512;
        FRAME_P4XOR: ram_conjdata_addra_pncode2check    <=  ram_conjdata_addra+512;
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
  .s_axis_a_tdata(m_fft_frame_check_data),          // input wire [47 : 0] s_axis_a_tdata
  
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode2check_r <=  m_ifft_Rxy_tvalid_pncode2check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode2check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode2check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode2check_r2 <=  m_ifft_Rxy_tvalid_pncode2check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode2check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode2check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode2check_r3 <=  m_ifft_Rxy_tvalid_pncode2check_r2;
end

reg [79:0]  Rxy_abs2_pncode2check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode2check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode2check_n0 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
  
  .s_axis_data_tdata(m_fft_frame_check_data),                      // input wire [47 : 0] s_axis_data_tdata
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxx0_tvalid_pncode2check)
            fft_sin_cut_abs2_pncode2check_multip <= fft_sin_cut_abs2_pncode2check_repart+fft_sin_cut_abs2_pncode2check_impart;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(fft_sin_cut_sum_abs2_pncode2check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode2check <=  fft_sin_cut_sum_abs2_pncode2check + fft_sin_cut_abs2_pncode2check_multip;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxy_tlast_pncode2check)
            flag_Rxy_abs2_pncode2check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode2check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode2check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode2check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode2check_d <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if({fft_sin_cut_sum_abs2_pncode2check_tvalid_r,fft_sin_cut_sum_abs2_pncode2check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode2check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode2check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode2check  <=  0;
    else if(state_r!=state)
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
//            FRAME_CODE1XOR: s_xcorr_divisor_tdata_pncode2check   <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;  
            FRAME_P2XOR:    s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
            FRAME_P3XOR:    s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;
            FRAME_P4XOR:    s_xcorr_divisor_tdata_pncode2check    <=  sqrt_R220_2_dimi65536 *fft_sin_cut_sum_abs2_pncode2check;

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


always@(posedge fifo7768_rdclk or negedge rstn)begin //对m_xcorr_dout_tvalid_pncode2check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode2check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode2check_r    <=  m_xcorr_dout_tvalid_pncode2check;


end


(* Mark_debug = "TRUE" *)reg [10:0] pncode2check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode2check_fraction_max <=  0;
    else if(state_r!=state)
        pncode2check_fraction_max <=  0;    
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))begin
        if(m_xcorr_dout_tvalid_pncode2check && (pncode2check_fraction>pncode2check_fraction_max))
           pncode2check_fraction_max<=pncode2check_fraction;
    end

end




always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)begin
        frame_p2code2_cfm   <=  0;
        frame_p3code2_cfm   <=  0;
        frame_p4code2_cfm   <=  0;
        end
    else if(state==FRAME_P2XOR)begin
        if({m_xcorr_dout_tvalid_pncode2check_r,m_xcorr_dout_tvalid_pncode2check}==2'b10)begin
            if(pncode2check_fraction_max>=Pn_XCOR_MAX)
                frame_p2code2_cfm   <=  1;            
        end
  
   end

    else if(state==FRAME_P3XOR)begin
        if({m_xcorr_dout_tvalid_pncode2check_r,m_xcorr_dout_tvalid_pncode2check}==2'b10)begin
            if(pncode2check_fraction_max>=Pn_XCOR_MAX)
                frame_p3code2_cfm   <=  1;            
        end
    end

    else if(state==FRAME_P4XOR)begin
        if({m_xcorr_dout_tvalid_pncode2check_r,m_xcorr_dout_tvalid_pncode2check}==2'b10)begin
            if(pncode2check_fraction_max>=Pn_XCOR_MAX)
                frame_p4code2_cfm   <=  1;            
        end
    end    
    
    else begin
         frame_p2code2_cfm  <=  frame_p2code2_cfm;
         frame_p3code2_cfm  <=  frame_p3code2_cfm;
         frame_p4code2_cfm  <=  frame_p4code2_cfm;
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
 
 

reg [10:0] ram_conjdata_addra_pncode3check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode3check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode3check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode3check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+768;
        FRAME_P3XOR: ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+768;
        FRAME_P4XOR: ram_conjdata_addra_pncode3check    <=  ram_conjdata_addra+768;
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
  .s_axis_a_tdata(m_fft_frame_check_data),          // input wire [47 : 0] s_axis_a_tdata
  
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode3check_r <=  m_ifft_Rxy_tvalid_pncode3check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode3check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode3check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode3check_r2 <=  m_ifft_Rxy_tvalid_pncode3check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode3check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode3check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode3check_r3 <=  m_ifft_Rxy_tvalid_pncode3check_r2;
end

reg [79:0]  Rxy_abs2_pncode3check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode3check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode3check_n0 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
  
  .s_axis_data_tdata(m_fft_frame_check_data),                      // input wire [47 : 0] s_axis_data_tdata
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxx0_tvalid_pncode3check)
            fft_sin_cut_abs2_pncode3check_multip <= fft_sin_cut_abs2_pncode3check_repart+fft_sin_cut_abs2_pncode3check_impart;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(fft_sin_cut_sum_abs2_pncode3check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode3check <=  fft_sin_cut_sum_abs2_pncode3check + fft_sin_cut_abs2_pncode3check_multip;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxy_tlast_pncode3check)
            flag_Rxy_abs2_pncode3check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode3check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode3check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode3check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode3check_d <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if({fft_sin_cut_sum_abs2_pncode3check_tvalid_r,fft_sin_cut_sum_abs2_pncode3check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode3check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode3check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode3check  <=  0;
    else if(state_r!=state)
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
//            FRAME_CODE1XOR: s_xcorr_divisor_tdata_pncode3check   <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;  
            FRAME_P2XOR:    s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
            FRAME_P3XOR:    s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;
            FRAME_P4XOR:    s_xcorr_divisor_tdata_pncode3check    <=  sqrt_R330_2_dimi65536 *fft_sin_cut_sum_abs2_pncode3check;

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


always@(posedge fifo7768_rdclk or negedge rstn)begin //对m_xcorr_dout_tvalid_pncode3check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode3check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode3check_r    <=  m_xcorr_dout_tvalid_pncode3check;


end


(* Mark_debug = "TRUE" *)reg [10:0] pncode3check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode3check_fraction_max <=  0;
    else if(state_r!=state)
        pncode3check_fraction_max <=  0;    
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))begin
        if(m_xcorr_dout_tvalid_pncode3check && (pncode3check_fraction>pncode3check_fraction_max))
           pncode3check_fraction_max<=pncode3check_fraction;
    end

end




always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)begin
        frame_p2code3_cfm   <=  0;
        frame_p3code3_cfm   <=  0;
        frame_p4code3_cfm   <=  0;
        end
    else if(state==FRAME_P2XOR)begin
        if({m_xcorr_dout_tvalid_pncode3check_r,m_xcorr_dout_tvalid_pncode3check}==2'b10)begin
            if(pncode3check_fraction_max>=Pn_XCOR_MAX)
                frame_p2code3_cfm   <=  1;            
        end
  
   end

    else if(state==FRAME_P3XOR)begin
        if({m_xcorr_dout_tvalid_pncode3check_r,m_xcorr_dout_tvalid_pncode3check}==2'b10)begin
            if(pncode3check_fraction_max>=Pn_XCOR_MAX)
                frame_p3code3_cfm   <=  1;            
        end
    end

    else if(state==FRAME_P4XOR)begin
        if({m_xcorr_dout_tvalid_pncode3check_r,m_xcorr_dout_tvalid_pncode3check}==2'b10)begin
            if(pncode3check_fraction_max>=Pn_XCOR_MAX)
                frame_p4code3_cfm   <=  1;            
        end
    end    
    
    else begin
         frame_p2code3_cfm  <=  frame_p2code3_cfm;
         frame_p3code3_cfm  <=  frame_p3code3_cfm;
         frame_p4code3_cfm  <=  frame_p4code3_cfm;
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




reg [10:0] ram_conjdata_addra_pncode4check;

always@(*)begin
    if(!rstn)
        ram_conjdata_addra_pncode4check <=  0;
    else if(state_r!=state)
        ram_conjdata_addra_pncode4check <=  0;
    else case(state)
    //    FRAME_SINXOR:   ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra;
    //    FRAME_CODE1XOR: ram_conjdata_addra_pncode4check <=  ram_conjdata_addra+256;
        FRAME_P2XOR: ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+1024;
        FRAME_P3XOR: ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+1024;
        FRAME_P4XOR: ram_conjdata_addra_pncode4check    <=  ram_conjdata_addra+1024;
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
  .s_axis_a_tdata(m_fft_frame_check_data),          // input wire [47 : 0] s_axis_a_tdata
  
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode4check_r <=  m_ifft_Rxy_tvalid_pncode4check;
end



always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode4check 延时2拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode4check_r2 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode4check_r2 <=  m_ifft_Rxy_tvalid_pncode4check_r;
end

always@(posedge fifo7768_rdclk)begin    //m_ifft_Rxy_tvalid_pncode4check 延时3拍 
    if(!rstn)
        m_ifft_Rxy_tvalid_pncode4check_r3 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        m_ifft_Rxy_tvalid_pncode4check_r3 <=  m_ifft_Rxy_tvalid_pncode4check_r2;
end

reg [79:0]  Rxy_abs2_pncode4check_n0 = 0;

always@(posedge fifo7768_rdclk)begin    
    if(!rstn)
        Rxy_abs2_pncode4check_n0 <=0 ;
    else if(state_r != state)
        Rxy_abs2_pncode4check_n0 <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
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
  
  .s_axis_data_tdata(m_fft_frame_check_data),                      // input wire [47 : 0] s_axis_data_tdata
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxx0_tvalid_pncode4check)
            fft_sin_cut_abs2_pncode4check_multip <= fft_sin_cut_abs2_pncode4check_repart+fft_sin_cut_abs2_pncode4check_impart;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(fft_sin_cut_sum_abs2_pncode4check_tvalid_r)
            fft_sin_cut_sum_abs2_pncode4check <=  fft_sin_cut_sum_abs2_pncode4check + fft_sin_cut_abs2_pncode4check_multip;
    else if(state_r != state)
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
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if(m_ifft_Rxy_tlast_pncode4check)
            flag_Rxy_abs2_pncode4check_d <= 1;

end
 
reg flag_fft_sum_abs2_pncode4check_d = 0; 
 
always@(posedge fifo7768_rdclk)begin   // fft_sin_cut_sum_abs2_pncode4check 计算完成的标志信号
    if(!rstn)
        flag_fft_sum_abs2_pncode4check_d <=  0;
    else if(state_r != state)
        flag_fft_sum_abs2_pncode4check_d <=  0;
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))
        if({fft_sin_cut_sum_abs2_pncode4check_tvalid_r,fft_sin_cut_sum_abs2_pncode4check_tvalid}==2'b10)
            flag_fft_sum_abs2_pncode4check_d <= 1;

end 
 

reg [9:0] cnt_fifo_Rxy_abs2_pncode4check = 0;


always@(posedge fifo7768_rdclk)begin
    if(!rstn)
        cnt_fifo_Rxy_abs2_pncode4check  <=  0;
    else if(state_r!=state)
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
//            FRAME_CODE1XOR: s_xcorr_divisor_tdata_pncode4check   <=  sqrt_R110_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;  
            FRAME_P2XOR:    s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
            FRAME_P3XOR:    s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;
            FRAME_P4XOR:    s_xcorr_divisor_tdata_pncode4check    <=  sqrt_R440_2_dimi65536 *fft_sin_cut_sum_abs2_pncode4check;

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


always@(posedge fifo7768_rdclk or negedge rstn)begin //对m_xcorr_dout_tvalid_pncode4check 延时一拍，上升沿检测第一个数据是否大于750
    if(!rstn)
        m_xcorr_dout_tvalid_pncode4check_r   <=  0;
    else 
        m_xcorr_dout_tvalid_pncode4check_r    <=  m_xcorr_dout_tvalid_pncode4check;


end


(* Mark_debug = "TRUE" *)reg [10:0] pncode4check_fraction_max;

always@(posedge fifo7768_rdclk)begin //获取归一化相关函数最大值
    if(!rstn)
        pncode4check_fraction_max <=  0;
    else if(state_r!=state)
        pncode4check_fraction_max <=  0;    
    else if((state==FRAME_P2XOR)||(state==FRAME_P3XOR)||(state==FRAME_P4XOR))begin
        if(m_xcorr_dout_tvalid_pncode4check && (pncode4check_fraction>pncode4check_fraction_max))
           pncode4check_fraction_max<=pncode4check_fraction;
    end

end




always@(posedge fifo7768_rdclk or negedge rstn)begin
    if(!rstn)begin
        frame_p2code4_cfm   <=  0;
        frame_p3code4_cfm   <=  0;
        frame_p4code4_cfm   <=  0;
        end
    else if(state==FRAME_P2XOR)begin
        if({m_xcorr_dout_tvalid_pncode4check_r,m_xcorr_dout_tvalid_pncode4check}==2'b10)begin
            if(pncode4check_fraction_max>=Pn_XCOR_MAX)
                frame_p2code4_cfm   <=  1;            
        end
  
   end

    else if(state==FRAME_P3XOR)begin
        if({m_xcorr_dout_tvalid_pncode4check_r,m_xcorr_dout_tvalid_pncode4check}==2'b10)begin
            if(pncode4check_fraction_max>=Pn_XCOR_MAX)
                frame_p3code4_cfm   <=  1;            
        end
    end

    else if(state==FRAME_P4XOR)begin
        if({m_xcorr_dout_tvalid_pncode4check_r,m_xcorr_dout_tvalid_pncode4check}==2'b10)begin
            if(pncode4check_fraction_max>=Pn_XCOR_MAX)
                frame_p4code4_cfm   <=  1;            
        end
    end    
    
    else begin
         frame_p2code4_cfm  <=  frame_p2code4_cfm;
         frame_p3code4_cfm  <=  frame_p3code4_cfm;
         frame_p4code4_cfm  <=  frame_p4code4_cfm;
         end
        
end



/*************    pncode4_check    end      ************/    
/*************    pncode4_check    end      ************/  
/*************    pncode4_check    end      ************/  
/*************    pncode4_check    end      ************/  

 
    
endmodule
