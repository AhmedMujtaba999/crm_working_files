import 'package:crm/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'package:uuid/uuid.dart';
import 'storage.dart';
import 'widgets.dart';

class CreateWorkItemPage extends StatefulWidget {
  final TaskItem? prefillTask;
  const CreateWorkItemPage({super.key, this.prefillTask});

  @override
  State<CreateWorkItemPage> createState() => _CreateWorkItemPageState();
}

enum CustomerExistsAction { cancel, openExisting, createNew }

class _CreateWorkItemPageState extends State<CreateWorkItemPage> {
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final addressC = TextEditingController();
  final notesC = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final amountC = TextEditingController();

  bool _isSaving = false;

  // If user selects "Create New" for an existing customer, we remember the phone
  // so the next Save will create the new work item without re-showing the dialog.
  String? _confirmedCreateForPhone;

  Future<CustomerExistsAction> showCustomerExistsDialog(
    BuildContext context,
    String phone,
    String email,
  ) async {
    final normPhone = phone.replaceAll(RegExp(r'\D'), '');
    final normEmail = email.trim().toLowerCase();
    final existing = await AppDb.instance.findLatestWorkItemByCustomer(phone: normPhone, email: normEmail);

    final res = await showDialog<CustomerExistsAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Customer Already Exists", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ]),
                    )
                  ],
                ),
                const SizedBox(height: 12),

                if (existing != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEFEFEF)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(existing.customerName, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      if (existing.email.trim().isNotEmpty) Text(existing.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 4),
                      if (existing.address.trim().isNotEmpty) Text(existing.address, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                  ),

                const SizedBox(height: 12),
                const Text(
                  "A customer with this contact already exists. You can open their latest record or create a new work item with their basic details prefilled.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, CustomerExistsAction.openExisting),
                          child: const Text("Open Existing"),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, CustomerExistsAction.createNew),
                          child: const Text("Create New"),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, CustomerExistsAction.cancel),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return res ?? CustomerExistsAction.cancel;
  }

  final demoServices = const [
    'Select service',
    'Water Change',
    'Filter Service',
    'Pool Cleaning',
    'Chemical Treatment',
  ];

  String selectedService = 'Select service';
  final List<ServiceItem> services = [];

  double get total => services.fold(0.0, (p, e) => p + e.amount);

  @override
  void initState() {
    super.initState();
    final t = widget.prefillTask;
    if (t != null) {
      nameC.text = t.customerName;
      phoneC.text = t.phone;
      emailC.text = t.email;
      addressC.text = t.address;
    }

    phoneC.addListener(() {
      final currentNormalized = phoneC.text.trim().replaceAll(RegExp(r'\D'), '');
      if (_confirmedCreateForPhone != null && currentNormalized != _confirmedCreateForPhone) {
        setState(() => _confirmedCreateForPhone = null);
      }
    });
  }

  @override
  void dispose() {
    nameC.dispose();
    phoneC.dispose();
    emailC.dispose();
    addressC.dispose();
    notesC.dispose();
    amountC.dispose();
    super.dispose();
  }

  Widget _buildTextFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          Icon(icon, color: AppColors.subText, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.subText, fontWeight: FontWeight.w700)),
        ],
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    ]);
  }

  void addService() {
    final amt = double.tryParse(amountC.text.trim());
    if (selectedService == 'Select service') return;
    if (amt == null || amt <= 0) return;

    final amtRounded = (amt * 100).round() / 100.0;

    if (services.any((s) => s.name == selectedService)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service already added')));
      return;
    }

    setState(() {
      services.add(ServiceItem(
        id: const Uuid().v4(),
        workItemId: 'temp',
        name: selectedService,
        amount: amtRounded,
      ));
      amountC.clear();
      selectedService = 'Select service';
    });
  }

  Future<void> saveWorkItem() async {
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid) return;

    if (services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least one service")));
      return;
    }

    final name = nameC.text.trim();

    final rawPhone = phoneC.text.trim();
    final rawEmail = emailC.text.trim();

    final phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    final email = rawEmail.toLowerCase();

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      bool exists = false;
      if (phone.isNotEmpty || email.isNotEmpty) {
        exists = await AppDb.instance.customerExists(phone: phone, email: email);
      }

      final skipDialog = (_confirmedCreateForPhone != null && _confirmedCreateForPhone == phone);

      if (exists && !skipDialog) {
        final action = await showCustomerExistsDialog(context, rawPhone, rawEmail);
        if (action == CustomerExistsAction.cancel) {
          setState(() => _isSaving = false);
          return;
        }

        if (action == CustomerExistsAction.openExisting) {
          final existing = await AppDb.instance.findLatestWorkItemByCustomer(phone: phone, email: email);
          if (existing != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening existing work item')));
            setState(() => _isSaving = false);

            // Open invoice page for that work item
            Navigator.pushNamed(context, '/invoice', arguments: existing.id);
            return;
          }
        }

        if (action == CustomerExistsAction.createNew) {
          final existing = await AppDb.instance.findLatestWorkItemByCustomer(phone: phone, email: email);
          if (existing != null) {
            setState(() {
              if (nameC.text.trim().isEmpty) nameC.text = existing.customerName;
              if (phoneC.text.trim().isEmpty) phoneC.text = existing.phone;
              if (emailC.text.trim().isEmpty) emailC.text = existing.email;
              if (addressC.text.trim().isEmpty) addressC.text = existing.address;

              _confirmedCreateForPhone = phone;
            });

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Prefilled details — review and tap Save again to create new work item')),
            );
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      if (_confirmedCreateForPhone != null && _confirmedCreateForPhone == phone) {
        _confirmedCreateForPhone = null;
      }

      final id = const Uuid().v4();
      final roundedTotal = (total * 100).round() / 100.0;

      final item = WorkItem(
        id: id,
        status: 'active',
        createdAt: DateTime.now(),
        customerName: name,
        phone: rawPhone,
        email: rawEmail,
        address: addressC.text.trim(),
        notes: notesC.text.trim(),
        total: roundedTotal,
      );

      final mapped = services
          .map((s) => ServiceItem(
                id: s.id,
                workItemId: id,
                name: s.name,
                amount: s.amount,
              ))
          .toList();

      await AppDb.instance.insertWorkItem(item, mapped);

      if (!mounted) return;

      // ✅ REQUIRED: after saving, go to Work Items -> Active
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'tab': 1, 'workTab': 'active'},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        const GradientHeader(title: "Create Work Item"),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              CardBox(
                title: "Customer Details",
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    _buildTextFormField(
                      label: "Customer Name",
                      hint: "Enter customer name",
                      icon: Icons.person_outline,
                      controller: nameC,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      label: "Phone Number",
                      hint: "Enter phone number",
                      icon: Icons.phone_outlined,
                      controller: phoneC,
                      keyboard: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-\(\)]'))],
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        final digits = t.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 6) return 'Enter a valid phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      label: "Email",
                      hint: "Enter email address",
                      icon: Icons.email_outlined,
                      controller: emailC,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        if (!re.hasMatch(t)) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextFormField(
                      label: "Address",
                      hint: "Enter address",
                      icon: Icons.location_on_outlined,
                      controller: addressC,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              CardBox(
                title: "Services",
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedService,
                            isExpanded: true,
                            items: demoServices.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => selectedService = v ?? selectedService),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 95,
                      child: TextField(
                        controller: amountC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                        decoration: InputDecoration(
                          hintText: "Amount",
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF2F5BFF)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: addService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F5BFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (services.isNotEmpty) ...[
                    ...services.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ServiceRow(
                            name: s.name,
                            amount: s.amount,
                            onDelete: () => setState(() => services.remove(s)),
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Amount", style: TextStyle(fontWeight: FontWeight.w900)),
                        Text("\$${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2F5BFF))),
                      ],
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              CardBox(
                title: "Notes (Optional)",
                child: TextField(
                  controller: notesC,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Add any additional notes or remarks...",
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2F5BFF)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                text: _isSaving ? "Saving…" : "Save Work Item",
                onTap: _isSaving ? null : saveWorkItem,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
