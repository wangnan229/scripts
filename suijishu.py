#!/usr/bin/python
# -*- coding:utf-8 -*-
# Author:zhenghanchao
# python suijishu.py 12
import random
import string
import sys
def generate_random_str(randomlength=16):
    """
    生成一个指定长度的随机字符串，其中
    string.digits=0123456789
    string.ascii_letters=abcdefghigklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ
    """
    str_list = [random.choice(string.digits + string.ascii_letters) for i in range(randomlength)]
    random_str = ''.join(str_list)
    return random_str

if __name__=='__main__':
    print(generate_random_str(int(sys.argv[1])))
