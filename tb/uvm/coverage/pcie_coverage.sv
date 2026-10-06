class pcie_coverage extends uvm_subscriber #(
  pcie_seq_item
);

  `uvm_component_utils(pcie_coverage)


  tlp_kind_e kind_sample;

  bit direction_sample;

  bit [9:0] length_sample;

  bit [3:0] first_be_sample;

  cpl_status_e status_sample;


  covergroup pcie_cg;

    option.per_instance = 1;


    cp_direction:
      coverpoint direction_sample {
        bins RX = {0};
        bins TX = {1};
      }


    cp_kind:
      coverpoint kind_sample {

        bins MEM_RD =
          {TLP_KIND_MEM_RD};

        bins MEM_WR =
          {TLP_KIND_MEM_WR};

        bins CPL =
          {TLP_KIND_CPL};

        bins CPLD =
          {TLP_KIND_CPLD};

        bins UNSUPPORTED =
          {TLP_KIND_UNSUPPORTED};

      }


cp_length:
  coverpoint length_sample {
    bins one_dw = {1};
  }


cp_first_be:
  coverpoint first_be_sample {
    bins full    = {4'hF};
    bins partial = {[4'h1:4'hE]};
  }


cp_status:
  coverpoint status_sample {
    bins SC = {CPL_STATUS_SC};
    bins UR = {CPL_STATUS_UR};
    bins CA = {CPL_STATUS_CA};
  }


    direction_kind_cross:
      cross cp_direction,
            cp_kind;

  endgroup


  function new(
    string name = "pcie_coverage",
    uvm_component parent = null
  );

    super.new(name, parent);

    pcie_cg = new();

  endfunction


  virtual function void write(
    pcie_seq_item t
  );

    direction_sample =
      t.direction;

    kind_sample =
      t.kind;

    length_sample =
      t.length_dw;

    first_be_sample =
      t.first_be;

    status_sample =
      t.cpl_status;


    pcie_cg.sample();

  endfunction


endclass