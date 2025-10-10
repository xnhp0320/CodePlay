module tbm;
import tbmlib_bitmap;
import std::io;

fn int main(String[] args)
{
    tbmlib_bitmap::print_inl_check_map{7}(io::stdout());
	return 0;
}
