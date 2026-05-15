import AppKit

extension DemoWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        sidebarItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard sidebarItems.indices.contains(row) else {
            return nil
        }
        let item = sidebarItems[row]
        let cell = tableView.makeView(withIdentifier: sidebarCellIdentifier, owner: self) as? NSTableCellView ?? makeSidebarCell()
        cell.textField?.stringValue = item.title
        if case .file(let url) = item.id {
            cell.toolTip = url.path
        } else {
            cell.toolTip = nil
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard sidebarItems.indices.contains(row) else {
            return
        }
        currentItemID = sidebarItems[row].id
        applySelectedNote(preloadBothViews: false)
    }

    private func makeSidebarCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = sidebarCellIdentifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        cell.addSubview(textField)
        cell.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
}
