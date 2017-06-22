#!/usr/bin/perl

package TBCsv;

use utf8;

our $FIELD_LIST = [
#宝贝名称
"t_title"                             ,
#宝贝类目
"t_cid"                                ,
#店铺类目
"t_seller_cids"                        ,
#新旧程度
"t_stuff_status"                       ,
#省
"t_location_state"                     ,
#城市
"t_location_city"                      ,
#出售方式
"t_item_type"                          ,
#宝贝价格
"t_price"                              ,
#加价幅度
"t_auction_increment"                  ,
#宝贝数量
"t_num"                                ,
#有效期
"t_valid_thru"                         ,
#运费承担
"t_freight_payer"                      ,
#平邮
"t_post_fee"                           ,
#EMS
"t_ems_fee"                            ,
#快递
"t_express_fee"                        ,
#发票
"t_has_invoice"                        ,
#保修
"t_has_warranty"                       ,
#放入仓库
"t_approve_status"                     ,
#橱窗推荐
"t_has_showcase"                       ,
#开始时间
"t_list_time"                          ,
#宝贝描述
"t_description"                        ,
#宝贝属性
"t_cateProps"                          ,
#邮费模版ID
"t_postage_id"                         ,
#会员打折
"t_has_discount"                       ,
#修改时间
"t_modified"                           ,
#上传状态
"t_upload_fail_msg"                    ,
#图片状态
"t_picture_status"                     ,
#返点比例
"t_auction_point"                      ,
#新图片
"t_picture"                            ,
#视频
"t_video"                              ,
#销售属性组合
"t_skuProps"                           ,
#用户输入ID串
"t_inputPids"                          ,
#用户输入名-值对
"t_inputValues"                        ,
#商家编码
"t_outer_id"                           ,
#销售属性别名
"t_propAlias"                          ,
#代充类型
"t_auto_fill"                          ,
#数字ID
"t_num_id"                             ,
#本地ID
"t_local_cid"                          ,
#宝贝分类
"t_navigation_type"                    ,
#用户名称
"t_user_name"                          ,
#宝贝状态
"t_syncStatus"                         ,
#闪电发货
"t_is_lighting_consigment"             ,
#新品
"t_is_xinpin"                          ,
#食品专项
"t_foodparame"                         ,
#尺码库
"t_features"                           ,
#采购地
"t_buyareatype"                        ,
#库存类型
"t_global_stock_type"                  ,
#国家地区
"t_global_stock_country"               ,
#库存计数
"t_sub_stock_type"                     ,
#物流体积
"t_item_size"                          ,
#物流重量
"t_item_weight"                        ,
#退换货承诺
"t_sell_promise"                       ,
#定制工具
"t_custom_design_flag"                 ,
#无线详情
"t_wireless_desc"                      ,
#商品条形码
"t_barcode"                            ,
#sku 条形码
"t_sku_barcode"                        ,
#7天退货
"t_newprepay"                          ,
#宝贝卖点
"t_subtitle"                           ,
#属性值备注
"t_cpv_memo"                           ,
#自定义属性值
"t_input_custom_cpv"                   ,
#商品资质
"t_qualification"                      ,
#增加商品资质
"t_add_qualification"                  ,
#关联线下服务
"t_o2o_bind_service"                   ,
#tmall扩展字段
"t_tmall_extend"                       ,
#产品组合
"t_product_combine"                    ,
#tmall属性组合
"t_tmall_item_prop_combine"            ,
#taoschema扩展字段
"t_taoschema_extend"                   ,
];


1;

