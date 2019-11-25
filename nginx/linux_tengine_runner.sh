#!/usr/bin/env bash

set -ex

export_or_prefix() {
    export OPENRESTY_PREFIX="/usr/local/openresty-debug"
}

before_install() {
	yum install luarocks -y
	yum install openssl-devel pcre-devel zlib-devel luarocks -y
    #sudo cpanm --notest Test::Nginx >build.log 2>&1 || (cat build.log && exit 1)
}

tengine_install() {
    if [ -d "build-cache${OPENRESTY_PREFIX}" ]; then
        # sudo rm -rf build-cache${OPENRESTY_PREFIX}
        sudo mkdir -p ${OPENRESTY_PREFIX}
        sudo cp -r build-cache${OPENRESTY_PREFIX}/* ${OPENRESTY_PREFIX}/
        ls -l ${OPENRESTY_PREFIX}/
        ls -l ${OPENRESTY_PREFIX}/bin
        return
    fi

    wget https://openresty.org/download/openresty-1.15.8.2.tar.gz
    tar zxf openresty-1.15.8.2.tar.gz

    wget http://tengine.taobao.org/download/tengine-2.3.2.tar.gz
    tar zxf tengine-2.3.2.tar.gz

    wget https://codeload.github.com/openresty/luajit2/tar.gz/v2.1-20190912
    tar zxf v2.1-20190912

    wget https://codeload.github.com/simplresty/ngx_devel_kit/tar.gz/v0.3.1
    tar zxf v0.3.1

    rm -rf openresty-1.15.8.2/bundle/nginx-1.15.8
    mv tengine-2.3.2 openresty-1.15.8.2/bundle/

    rm -rf openresty-1.15.8.2/bundle/LuaJIT-2.1-20190507
    mv luajit2-2.1-20190912 openresty-1.15.8.2/bundle/

    rm -rf openresty-1.15.8.2/bundle/ngx_devel_kit-0.3.1rc1
    mv ngx_devel_kit-0.3.1 openresty-1.15.8.2/bundle/

    sed -i "s/= auto_complete 'LuaJIT';/= auto_complete 'luajit2';/g" openresty-1.15.8.2/configure
    sed -i 's/= auto_complete "nginx";/= auto_complete "tengine";/g' openresty-1.15.8.2/configure

    cd openresty-1.15.8.2

    ./configure --prefix=${OPENRESTY_PREFIX} --with-debug \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_degradation_module \
        --with-http_flv_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-stream_ssl_preread_module \
        --with-stream_sni \
        --with-pcre \
        --with-pcre-jit \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --add-module=bundle/tengine-2.3.2/modules/ngx_http_upstream_vnswrr_module/ \
        --add-module=bundle/tengine-2.3.2/modules/mod_dubbo \
        --add-module=bundle/tengine-2.3.2/modules/ngx_multi_upstream_module \
        --add-module=bundle/tengine-2.3.2/modules/mod_config \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_concat_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_footer_filter_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_proxy_connect_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_reqstat_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_slice_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_sysguard_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_trim_filter_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_upstream_check_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_upstream_consistent_hash_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_upstream_dynamic_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_upstream_dyups_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_upstream_session_sticky_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_http_user_agent_module \
        --add-dynamic-module=bundle/tengine-2.3.2/modules/ngx_slab_stat \
        > build.log 2>&1 || (cat build.log && exit 1)

    make > build.log 2>&1 || (cat build.log && exit 1)

    sudo PATH=$PATH make install > build.log 2>&1 || (cat build.log && exit 1)

    cd ..

    mkdir -p build-cache${OPENRESTY_PREFIX}
    cp -r ${OPENRESTY_PREFIX}/* build-cache${OPENRESTY_PREFIX}
    ls build-cache${OPENRESTY_PREFIX}
    rm -rf openresty-1.15.8.2
}
