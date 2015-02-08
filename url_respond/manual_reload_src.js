
var GyFXHnTVYFd0_under_mouse = nil;

function GyFXHnTVYFd0_cur_img_under_src() {
    if(GyFXHnTVYFd0_under_mouse) {
        var list = GyFXHnTVYFd0_under_mouse.getElementsByTagName('img');
        if(list.length == 1){ return list[0].src; }
        return "none" + list.length
    } else {
        return "no_under"
    }
}

document.getElementsByTagName("body")[0].onmousemove =
    function(event){ GyFXHnTVYFd0_under_mouse = event.target; }
