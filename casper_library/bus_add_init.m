function bus_add_init(blk, varargin)

  clog('entering bus_add_init', 'trace');
  
  defaults = { ...
    'operation', 'a+b', ...
    'n_bits_a', [8 8 8 8 8 8 8 8] ,  'bin_pt_a',     [3],   'type_a',   1, ...
    'n_bits_b', [4 4 4 4 4 4 4 4]  ,  'bin_pt_b',     [3],   'type_b',   [1], ...
    'n_bits_out', 8 ,     'bin_pt_out',   [3],   'type_out', [1], ...
    'overflow', [1], 'quantization', [0], 'add_latency', 1, ...
    'cmplx', 'on', 'misc', 'on'
  };  
  
  check_mask_type(blk, 'bus_add');

  if same_state(blk, 'defaults', defaults, varargin{:}), return, end
  munge_block(blk, varargin{:});

  xpos = 50; xinc = 80;
  ypos = 50; yinc = 50;

  port_w = 30; port_d = 14;
  bus_expand_w = 50;
  bus_create_w = 50;
  add_w = 50; add_d = 60;
  del_w = 30; del_d = 20;

  operation    = get_var('operation', 'defaults', defaults, varargin{:});
  n_bits_a     = get_var('n_bits_a', 'defaults', defaults, varargin{:});
  bin_pt_a     = get_var('bin_pt_a', 'defaults', defaults, varargin{:});
  type_a       = get_var('type_a', 'defaults', defaults, varargin{:});
  n_bits_b     = get_var('n_bits_b', 'defaults', defaults, varargin{:});
  bin_pt_b     = get_var('bin_pt_b', 'defaults', defaults, varargin{:});
  type_b       = get_var('type_b', 'defaults', defaults, varargin{:});
  n_bits_out   = get_var('n_bits_out', 'defaults', defaults, varargin{:});
  bin_pt_out   = get_var('bin_pt_out', 'defaults', defaults, varargin{:});
  type_out     = get_var('type_out', 'defaults', defaults, varargin{:});
  overflow     = get_var('overflow', 'defaults', defaults, varargin{:});
  quantization = get_var('quantization', 'defaults', defaults, varargin{:});
  add_latency  = get_var('add_latency', 'defaults', defaults, varargin{:});
  misc         = get_var('misc', 'defaults', defaults, varargin{:});
  cmplx        = get_var('cmplx', 'defaults', defaults, varargin{:});
 
  delete_lines(blk);

  %default state, do nothing 
  if (n_bits_a == 0) || (n_bits_b == 0),
    clean_blocks(blk);
    save_state(blk, 'defaults', defaults, varargin{:});  % Save and back-populate mask parameter values
    clog('exiting bus_add_init','trace');
    return;
  end
 
  lenba = length(n_bits_a); lenpa = length(bin_pt_a); lenta = length(type_a);
  a = [lenba, lenpa, lenta];  

  lenbb = length(n_bits_b); lenpb = length(bin_pt_b); lentb = length(type_b);
  b = [lenbb, lenpb, lentb];  

  lenbo = length(n_bits_out); lenpo = length(bin_pt_out); lento = length(type_out); 
  lenq = length(quantization); leno = length(overflow);
  o = [lenbo, lenpo, lento, lenq, leno];

  comps = unique([a, b, o]);
  %if have more than 2 unique components or have two but one isn't 1
  if ((length(comps) > 2) | (length(comps) == 2 && comps(1) ~= 1)),
    clog('conflicting component sizes','error');
    return;
  end

  %determine number of components from clues   
  compa = max(a); compb = max(b); compo = max(o); comp = max(compa, compb);

  %need to specify at least one set of input components
  if compo > comp,
    clog('more output components than inputs','error');
    return;
  end

  %replicate items if needed for a input
  n_bits_a    = repmat(n_bits_a, 1, compa/lenba);
  bin_pt_a    = repmat(bin_pt_a, 1, compa/lenpa);
  type_a      = repmat(type_a, 1, compa/lenta);
  
  %replicate items if needed for b input
  n_bits_b    = repmat(n_bits_b, 1, compb/lenbb);
  bin_pt_b    = repmat(bin_pt_b, 1, compb/lenpb);
  type_b      = repmat(type_b, 1, compb/lentb);

  %need to pad output if need more than one
  n_bits_out    = repmat(n_bits_out, 1, comp/lenbo);
  bin_pt_out    = repmat(bin_pt_out, 1, comp/lenpo);
  type_o        = repmat(type_out, 1, comp/lento);
  overflow      = repmat(overflow, 1, comp/leno);
  quantization  = repmat(quantization, 1, comp/leno);

  %if complex we need to double down on some of these
  if strcmp(cmplx, 'on'),
    compa       = compa*2;
    n_bits_a    = reshape([n_bits_a; n_bits_a], 1, compa);
    bin_pt_a    = reshape([bin_pt_a; bin_pt_a], 1, compa);
    type_a      = reshape([type_a; type_a], 1, compa);
    
    compb       = compb*2;
    n_bits_b    = reshape([n_bits_b; n_bits_b], 1, compb);
    bin_pt_b    = reshape([bin_pt_b; bin_pt_b], 1, compb);
    type_b      = reshape([type_b; type_b], 1, compb);

    comp          = comp*2;
    n_bits_out    = reshape([n_bits_out; n_bits_out], 1, comp);
    bin_pt_out    = reshape([bin_pt_out; bin_pt_out], 1, comp);
    type_o        = reshape([type_o; type_o], 1, comp);
    overflow      = reshape([overflow; overflow], 1, comp);
    quantization  = reshape([quantization; quantization], 1, comp);
  end

  %input ports
  ypos_tmp = ypos + add_d*compa/2;
  reuse_block(blk, 'a', 'built-in/inport', ...
    'Port', '1', 'Position', [xpos-port_w/2 ypos_tmp-port_d/2 xpos+port_w/2 ypos_tmp+port_d/2]);
  ypos_tmp = ypos_tmp + yinc + add_d*(compa/2 + compb/2);
  
  reuse_block(blk, 'b', 'built-in/inport', ...
    'Port', '2', 'Position', [xpos-port_w/2 ypos_tmp-port_d/2 xpos+port_w/2 ypos_tmp+port_d/2]);
  ypos_tmp = ypos_tmp + yinc + add_d*compb/2;

  if strcmp(misc, 'on'),
    reuse_block(blk, 'misci', 'built-in/inport', ...
      'Port', '3', 'Position', [xpos-port_w/2 ypos_tmp-port_d/2 xpos+port_w/2 ypos_tmp+port_d/2]);
  end
  xpos = xpos + xinc + port_w/2;  

  % bus expand
  ypos_tmp = ypos + add_d*compa/2; %reset ypos
  
  reuse_block(blk, 'a_debus', 'casper_library_flow_control/bus_expand', ...
    'mode', 'divisions of arbitrary size', ...
    'outputWidth', ['[',num2str(n_bits_a),']'], ...
    'outputBinaryPt', ['[',num2str(bin_pt_a),']'], ...
    'outputArithmeticType', ['[',num2str(type_a),']'], ...
    'show_format', 'on', 'outputToWorkspace', 'off', ...
    'variablePrefix', '', 'outputToModelAsWell', 'on', ...
    'Position', [xpos-bus_expand_w/2 ypos_tmp-add_d*compa/2 xpos+bus_expand_w/2 ypos_tmp+add_d*compa/2]);
  add_line(blk, 'a/1', 'a_debus/1');
  ypos_tmp = ypos_tmp + add_d*(compa/2+compb/2) + yinc;
  
  reuse_block(blk, 'b_debus', 'casper_library_flow_control/bus_expand', ...
    'mode', 'divisions of arbitrary size', ...
    'outputWidth', ['[',num2str(n_bits_b),']'], ...
    'outputBinaryPt', ['[',num2str(bin_pt_b),']'], ...
    'outputArithmeticType', ['[',num2str(type_b),']'], ...
    'show_format', 'on', 'outputToWorkspace', 'off', ...
    'variablePrefix', '', 'outputToModelAsWell', 'on', ...
    'Position', [xpos-bus_expand_w/2 ypos_tmp-add_d*compb/2 xpos+bus_expand_w/2 ypos_tmp+add_d*compb/2]);
  add_line(blk, 'b/1', 'b_debus/1');
  ypos_tmp = ypos_tmp + add_d*compa + yinc;

  %addition
  xpos = xpos + xinc + add_w/2;  
  ypos_tmp = ypos; %reset ypos 

  %need adder per component
  a_src = repmat([1:compa], 1, comp/compa);
  b_src = repmat([1:compb], 1, comp/compb);

  clog(['making ',num2str(comp),' AddSubs'],'bus_add_init_debug');

  switch operation,
    case 'a+b',
      mode = 'Addition';
    case 'a-b',
      mode = 'Subtraction';
  end  

  for add_index = 1:comp
    switch type_o(add_index),
      case 0,
        arith_type = 'Unsigned';
      case 1,
        arith_type = 'Signed';
    end
    switch quantization(add_index),
      case 0,
        quant = 'Truncate';
      case 1,
        quant = 'Round  (unbiased: +/- Inf)';
    end  
    switch overflow(add_index),
      case 0,
        of = 'Wrap';
      case 1,
        of = 'Saturate';
      case 2,
        of = 'Flag as error';
    end  
        
    clog(['output ',num2str(add_index),': ', ... 
      ' a[',num2str(a_src(add_index)),'] + b[',num2str(b_src(add_index)),'] = ', ...
      '(',num2str(n_bits_out(add_index)), ' ', num2str(bin_pt_out(add_index)),') ' ...
      arith_type,' ',quant,' ', of], ...
      'bus_add_init_debug'); 

    add_name = ['add',num2str(add_index)]; 
    reuse_block(blk, add_name, 'xbsIndex_r4/AddSub', ...
      'mode', mode, 'latency', num2str(add_latency), ...
      'precision', 'User Defined', ...
      'n_bits', num2str(n_bits_out(add_index)), 'bin_pt', num2str(bin_pt_out(add_index)), ...  
      'arith_type', arith_type, 'quantization', quant, 'overflow', of, ... 
      'Position', [xpos-add_w/2 ypos_tmp xpos+add_w/2 ypos_tmp+add_d-20]);
    ypos_tmp = ypos_tmp + add_d;
  
    add_line(blk, ['a_debus/',num2str(a_src(add_index))], [add_name,'/1']);
    add_line(blk, ['b_debus/',num2str(b_src(add_index))], [add_name,'/2']);
  end %for

  ypos_tmp = ypos + add_d*(compb+compa) + 2*yinc;
  if strcmp(misc, 'on'),
    reuse_block(blk, 'dmisc', 'xbsIndex_r4/Delay', ...
      'latency', num2str(add_latency), ...
      'Position', [xpos-del_w/2 ypos_tmp-del_d/2 xpos+del_w/2 ypos_tmp+del_d/2]);
    add_line(blk, 'misci/1', 'dmisc/1');
  end
  xpos = xpos + xinc + add_d/2;

  %bus create 
  ypos_tmp = ypos + add_d*comp/2; %reset ypos
 
  reuse_block(blk, 'a+b_bussify', 'casper_library_flow_control/bus_create', ...
    'inputNum', num2str(comp), ...
    'Position', [xpos-bus_create_w/2 ypos_tmp-add_d*comp/2 xpos+bus_create_w/2 ypos_tmp+add_d*comp/2]);
  
  for index = 1:comp,
    add_line(blk, ['add',num2str(index),'/1'], ['a+b_bussify/',num2str(index)]);
  end

  %output port/s
  ypos_tmp = ypos + add_d*comp/2;
  xpos = xpos + xinc + bus_create_w/2;
  reuse_block(blk, 'a+b', 'built-in/outport', ...
    'Port', '1', 'Position', [xpos-port_w/2 ypos_tmp-port_d/2 xpos+port_w/2 ypos_tmp+port_d/2]);
  add_line(blk, ['a+b_bussify/1'], ['a+b/1']);
  ypos_tmp = ypos_tmp + yinc + port_d;  

  ypos_tmp = ypos + add_d*(compb+compa) + 2*yinc;
  if strcmp(misc, 'on'),
    reuse_block(blk, 'misco', 'built-in/outport', ...
      'Port', '2', ... 
      'Position', [xpos-port_w/2 ypos_tmp-port_d/2 xpos+port_w/2 ypos_tmp+port_d/2]);

    add_line(blk, 'dmisc/1', 'misco/1');
  end
  
  % When finished drawing blocks and lines, remove all unused blocks.
  clean_blocks(blk);

  save_state(blk, 'defaults', defaults, varargin{:});  % Save and back-populate mask parameter values

  clog('exiting bus_add_init','trace');

end %function bus_add_init

